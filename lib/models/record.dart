import 'package:cloud_firestore/cloud_firestore.dart';

class Record {
  final String id;
  final Map<String, dynamic> data;
  const Record(this.id, this.data);
  factory Record.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Record(doc.id, doc.data() ?? {});
  String s(String key) {
    if (key == 'start' && data['startAt'] is Timestamp) {
      return isoDay((data['startAt'] as Timestamp).toDate().toUtc());
    }
    if (key == 'end' && data['endAt'] is Timestamp) {
      return isoDay((data['endAt'] as Timestamp).toDate().toUtc());
    }
    return data[key]?.toString() ?? '';
  }

  int i(String key) => (data[key] as num?)?.toInt() ?? 0;
  double n(String key) => (data[key] as num?)?.toDouble() ?? 0;
  bool b(String key) => data[key] == true;
  List<String> list(String key) => (data[key] as List?)?.cast<String>() ?? [];
  DateTime? time(String key) => (data[key] as Timestamp?)?.toDate();
  String get name => '${s('firstName')} ${s('lastName')}';
  bool get isOwner => s('role') == 'owner';
  String get displayStatus {
    if (s('status') == 'confirmed' &&
        s('end').compareTo(isoDay(DateTime.now())) <= 0) {
      return 'completed';
    }
    if (s('status') == 'awaiting_payment' &&
        i('holdExpiresAt') <= DateTime.now().millisecondsSinceEpoch) {
      return 'expired';
    }
    return s('status');
  }
}

String isoDay(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String money(num minor) => '₪${(minor / 100).toStringAsFixed(2)}';
