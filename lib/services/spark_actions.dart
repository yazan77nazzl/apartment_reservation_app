import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Free-plan operations. Firestore rules, rather than a paid runtime, enforce
/// ownership and state changes. Real payment confirmation is intentionally denied.
class SparkActions {
  final FirebaseFirestore db;
  SparkActions(this.db);
  User get user => FirebaseAuth.instance.currentUser!;
  String get uid => user.uid;
  FieldValue get stamp => FieldValue.serverTimestamp();
  DocumentReference<Map<String, dynamic>> doc(String collection, String id) =>
      db.collection(collection).doc(id);
  Future<Map<String, dynamic>> profile() async =>
      (await doc('users', uid).get()).data()!;
  Future<Map<String, dynamic>> call(
      String name, Map<String, dynamic> data) async {
    switch (name) {
      case 'registerProfile':
        await doc('users', uid).set({
          for (final key in [
            'firstName',
            'lastName',
            'phone',
            'address',
            'role',
            'gender'
          ])
            key: data[key],
          'email': user.email,
          'photoUrl': '',
          'createdAt': stamp
        });
        return {'ok': true};
      case 'updateProfile':
        await doc('users', uid)
            .update({...data, 'email': user.email, 'updatedAt': stamp});
        return {'ok': true};
      case 'saveApartment':
        final p = await profile(),
            r = data['id'] == null
                ? db.collection('apartments').doc()
                : doc('apartments', data['id']);
        final values = {
          for (final key in [
            'title',
            'description',
            'location',
            'nearestGate',
            'gender',
            'housingType',
            'images'
          ])
            key: data[key] ?? (key == 'nearestGate' ? '' : null),
          'ownerId': uid,
          'ownerName': '${p['firstName']} ${p['lastName']}',
          'contactPhone': p['phone'],
          'updatedAt': stamp
        };
        if (data['id'] == null) {
          await r.set({
            ...values,
            'createdAt': stamp,
            'ratingSum': 0,
            'reviewCount': 0,
            'averageRating': 0,
            'minPriceMinor': 0
          });
        } else {
          await r.update(values);
        }
        return {'id': r.id};
      case 'saveRoom':
        final r = data['id'] == null
            ? db.collection('rooms').doc()
            : doc('rooms', data['id']);
        final values = {
          for (final key in [
            'apartmentId',
            'number',
            'floor',
            'beds',
            'priceMinor',
            'description',
            'available'
          ])
            key: data[key],
          'ownerId': uid,
          'updatedAt': stamp
        };
        if (data['id'] == null) {
          await r
              .set({...values, 'createdAt': stamp, 'activeReservationId': ''});
        } else {
          await r.update(values);
        }
        return {'id': r.id};
      case 'submitReservation':
        return _request(data);
      case 'decideReservation':
        return _decision(data);
      case 'cancelReservation':
        return _cancel(data);
      case 'demoPayment':
        throw StateError(
            'Sandbox payments run in the local Functions emulator. Real payments are unavailable on Spark.');
      case 'saveReview':
        return _review(data);
      case 'openChat':
        final p = await profile(),
            apartment =
                (await doc('apartments', data['apartmentId']).get()).data()!;
        final r = doc('chats', '${uid}_${apartment['ownerId']}');
        await db.runTransaction((tx) async {
          final s = await tx.get(r);
          if (!s.exists) {
            tx.set(r, {
              'participants': [uid, apartment['ownerId']],
              'studentId': uid,
              'ownerId': apartment['ownerId'],
              'studentName': '${p['firstName']} ${p['lastName']}',
              'ownerName': apartment['ownerName'],
              'apartmentId': data['apartmentId'],
              'latestMessage': '',
              'readAt': <String, dynamic>{},
              'updatedAt': stamp
            });
          }
        });
        return {'id': r.id};
      case 'sendMessage':
        final r = doc('chats', data['chatId']),
            m = r.collection('messages').doc(),
            batch = db.batch();
        batch.set(
            m, {'senderId': uid, 'body': data['body'], 'createdAt': stamp});
        batch.update(r, {
          'latestMessage': data['body'],
          'latestSenderId': uid,
          'latestMessageId': m.id,
          'updatedAt': stamp
        });
        await batch.commit();
        return {'id': m.id};
      case 'markChatRead':
        await doc('chats', data['chatId']).update({'readAt.$uid': stamp});
        return {'ok': true};
      case 'registerPushToken':
        throw StateError(
            'Automatic push delivery requires a trusted backend. In-app notifications are available on Spark.');
      default:
        throw StateError('Unsupported operation: $name');
    }
  }

  void _notification(Transaction tx, String id, Map<String, dynamic> r,
      String status, String recipient, String title) {
    tx.set(doc('notifications', '${id}_$status'), {
      'userId': recipient,
      'reservationId': id,
      'status': status,
      'title': title,
      'body': r['apartmentTitle'],
      'read': false,
      'createdAt': stamp
    });
  }

  Future<Map<String, dynamic>> _request(Map<String, dynamic> data) async {
    final p = await profile(),
        rr = doc('rooms', data['roomId']),
        r = db.collection('reservations').doc();
    final a = DateTime.parse('${data['start']}T00:00:00Z'),
        b = DateTime.parse('${data['end']}T00:00:00Z');
    final days = b.difference(a).inDays;
    if (days < 1 || days > 366) throw StateError('Choose a stay of 1–366 days');
    await db.runTransaction((tx) async {
      final room = (await tx.get(rr)).data()!,
          apartment =
              (await tx.get(doc('apartments', room['apartmentId']))).data()!;
      final values = {
        'studentId': uid,
        'ownerId': room['ownerId'],
        'apartmentId': room['apartmentId'],
        'roomId': rr.id,
        'apartmentTitle': apartment['title'],
        'roomNumber': room['number'],
        'studentName': '${p['firstName']} ${p['lastName']}',
        'studentAddress': p['address'],
        'studentPhone': p['phone'],
        'start': data['start'],
        'end': data['end'],
        'startAt': Timestamp.fromDate(a),
        'endAt': Timestamp.fromDate(b),
        'rentalMonths': (days / 30).ceil(),
        'amountMinor': room['priceMinor'] * (days / 30).ceil(),
        'currency': 'ILS',
        'status': 'pending',
        'paymentStatus': 'unpaid',
        'parentId': data['parentId'] ?? '',
        'createdAt': stamp
      };
      tx.set(r, values);
      _notification(tx, r.id, values, 'pending', room['ownerId'],
          'New reservation request');
    });
    return {'id': r.id};
  }

  Future<Map<String, dynamic>> _decision(Map<String, dynamic> data) async {
    final r = doc('reservations', data['id']);
    await db.runTransaction((tx) async {
      final reservation = (await tx.get(r)).data()!;
      if (reservation['status'] != 'pending') {
        throw StateError('Request is no longer pending');
      }
      final approve = data['action'] == 'approve',
          rr = doc('rooms', reservation['roomId']);
      final room = (await tx.get(rr)).data()!;
      final activeId = room['activeReservationId'] as String? ?? '';
      if (approve && activeId.isNotEmpty) {
        final active = (await tx.get(doc('reservations', activeId))).data();
        if (active != null &&
            active['status'] == 'awaiting_payment' &&
            (active['holdUntil'] as Timestamp)
                .toDate()
                .isAfter(DateTime.now())) {
          throw StateError(
              'This room already has an approved request. Cancel it or wait for its approval to expire.');
        }
        if (active != null &&
            ['confirmed', 'completed'].contains(active['status']) &&
            (active['endAt'] as Timestamp).toDate().isAfter(DateTime.now())) {
          throw StateError('Room has an active stay');
        }
      }
      final status = approve ? 'awaiting_payment' : 'rejected';
      final hold = DateTime.fromMillisecondsSinceEpoch(
          DateTime.now().millisecondsSinceEpoch + 24 * 3600000);
      tx.update(r, {
        'status': status,
        'holdUntil': Timestamp.fromDate(hold),
        'holdExpiresAt': hold.millisecondsSinceEpoch,
        'updatedAt': stamp
      });
      if (approve) tx.update(rr, {'activeReservationId': r.id});
      _notification(tx, r.id, reservation, status, reservation['studentId'],
          approve ? 'Reservation approved' : 'Reservation rejected');
    });
    return {'ok': true};
  }

  Future<Map<String, dynamic>> _cancel(Map<String, dynamic> data) async {
    final r = doc('reservations', data['id']);
    await db.runTransaction((tx) async {
      final reservation = (await tx.get(r)).data()!,
          rr = doc('rooms', reservation['roomId']);
      final room = (await tx.get(rr)).data()!;
      tx.update(r, {'status': 'cancelled', 'updatedAt': stamp});
      if (room['activeReservationId'] == r.id) {
        tx.update(rr, {'activeReservationId': ''});
      }
      _notification(
          tx,
          r.id,
          reservation,
          'cancelled',
          uid == reservation['studentId']
              ? reservation['ownerId']
              : reservation['studentId'],
          'Reservation cancelled');
    });
    return {'ok': true};
  }

  Future<Map<String, dynamic>> _review(Map<String, dynamic> data) async {
    // Existing verified paid stays may be reviewed. Spark clients cannot fabricate
    // payment confirmation or alter aggregate ratings; UI averages review records.
    final p = await profile(),
        r = doc('reviews', '${data['apartmentId']}_$uid');
    await r.set({
      'apartmentId': data['apartmentId'],
      'reservationId': data['reservationId'],
      'studentId': uid,
      'studentName': '${p['firstName']} ${p['lastName']}',
      'ownerId': (await doc('apartments', data['apartmentId']).get())
          .data()!['ownerId'],
      'rating': data['rating'],
      'comment': data['comment'],
      'updatedAt': stamp
    });
    return {'ok': true};
  }
}
