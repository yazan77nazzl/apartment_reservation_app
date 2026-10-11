import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../models/record.dart';
import 'image_storage.dart';
import 'spark_actions.dart';
import 'supabase_image_storage.dart';

final repositoryProvider = Provider((ref) => HousingRepository());

class HousingRepository {
  final db = FirebaseFirestore.instance;
  final functions = FirebaseFunctions.instanceFor(region: AppConfig.region);
  final ImageStorage imageStorage = switch (AppConfig.imageStorage) {
    'demo' => DemoImageStorage(),
    'firebase' => FirebaseImageStorage(),
    'supabase' => SupabaseImageStorage(),
    _ => throw StateError('Unsupported image storage provider'),
  };
  Stream<Record?> document(String collection, String id) {
    final stream = db.collection(collection).doc(id).snapshots();
    if (collection == 'apartments' && !AppConfig.useFunctions) {
      return _enrich(
              stream.map((s) => s.exists ? [Record.fromDoc(s)] : <Record>[]))
          .map((list) => list.isEmpty ? null : list.first);
    }
    return stream.map((s) => s.exists ? Record.fromDoc(s) : null);
  }

  Stream<List<Record>> records(String collection,
      {String? field, dynamic value, bool array = false, String? order}) {
    Query<Map<String, dynamic>> q = db.collection(collection);
    if (field != null) {
      q = array
          ? q.where(field, arrayContains: value)
          : q.where(field, isEqualTo: value);
    }
    if (order != null) q = q.orderBy(order, descending: true);
    final stream =
        q.snapshots().map((s) => s.docs.map(Record.fromDoc).toList());
    return collection == 'apartments' && !AppConfig.useFunctions
        ? _enrich(stream)
        : stream;
  }

  Stream<List<Record>> _enrich(Stream<List<Record>> source) {
    late StreamController<List<Record>> controller;
    final subscriptions = <StreamSubscription<List<Record>>>[];
    List<Record>? apartments, rooms, reviews;
    void emit() {
      if (apartments == null || rooms == null || reviews == null) return;
      controller.add(apartments!.map((a) {
        final prices = rooms!
            .where((r) => r.s('apartmentId') == a.id && r.b('available'))
            .map((r) => r.i('priceMinor'))
            .toList()
          ..sort();
        final apartmentReviews =
            reviews!.where((r) => r.s('apartmentId') == a.id).toList();
        final sum =
            apartmentReviews.fold<int>(0, (sum, r) => sum + r.i('rating'));
        return Record(a.id, {
          ...a.data,
          'minPriceMinor': prices.isEmpty ? 0 : prices.first,
          'reviewCount': apartmentReviews.length,
          'ratingSum': sum,
          'averageRating':
              apartmentReviews.isEmpty ? 0 : sum / apartmentReviews.length
        });
      }).toList());
    }

    controller = StreamController<List<Record>>(onListen: () {
      subscriptions.add(source.listen((v) {
        apartments = v;
        emit();
      }, onError: controller.addError));
      subscriptions.add(records('rooms').listen((v) {
        rooms = v;
        emit();
      }, onError: controller.addError));
      subscriptions.add(records('reviews').listen((v) {
        reviews = v;
        emit();
      }, onError: controller.addError));
    }, onCancel: () async {
      for (final s in subscriptions) {
        await s.cancel();
      }
    });
    return controller.stream;
  }

  Future<Map<String, dynamic>> call(
      String name, Map<String, dynamic> data) async {
    if (!AppConfig.useFunctions) return SparkActions(db).call(name, data);
    final result =
        await functions.httpsCallable(name).call<Map<String, dynamic>>(data);
    return result.data;
  }

  Future<String?> pickImage(String path, {required BuildContext context}) =>
      imageStorage.choose(context, path);

  Future<void> readNotification(String id) =>
      db.collection('notifications').doc(id).update({'read': true});
}
