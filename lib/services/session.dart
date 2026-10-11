import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/record.dart';
import '../core/config/app_config.dart';
import 'housing_repository.dart';

final sessionProvider =
    ChangeNotifierProvider((ref) => Session(ref.read(repositoryProvider)));
final localeProvider = StateProvider<String>((ref) => 'en');

class Session extends ChangeNotifier {
  final HousingRepository repository;
  User? user;
  Record? profile;
  bool loading = true;
  String? error;
  StreamSubscription<User?>? _auth;
  StreamSubscription<Record?>? _profile;
  StreamSubscription<String>? _tokens;
  Session(this.repository) {
    _auth = FirebaseAuth.instance.userChanges().listen(_changed,
        onError: (Object e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    });
  }
  Future<void> _changed(User? next) async {
    await _profile?.cancel();
    await _tokens?.cancel();
    user = next;
    profile = null;
    error = null;
    loading = next != null;
    notifyListeners();
    if (next == null) return;
    _profile = repository.document('users', next.uid).listen((p) {
      profile = p;
      loading = false;
      error = null;
      notifyListeners();
      if (p != null && next.email != p.s('email')) {
        repository.call(
            'updateProfile', {}).catchError((Object _) => <String, dynamic>{});
      }
    }, onError: (Object e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    });
  }

  Future<void> enablePush() async {
    if (!AppConfig.useFunctions) {
      throw StateError(
          'Automatic push delivery requires a trusted backend. In-app notifications are available on Spark.');
    }
    if (AppConfig.emulator) {
      throw StateError(
          'Push requires a configured Firebase project. In-app notifications work in the emulator.');
    }
    final permission = await FirebaseMessaging.instance.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      throw StateError('Notification permission was denied');
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await repository.call('registerPushToken', {'token': token});
    }
    await _tokens?.cancel();
    _tokens = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      repository.call('registerPushToken', {'token': token}).catchError(
          (Object _) => <String, dynamic>{});
    });
  }

  Future<void> logout() async {
    if (!AppConfig.emulator) {
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }
    await FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    _auth?.cancel();
    _profile?.cancel();
    _tokens?.cancel();
    super.dispose();
  }
}
