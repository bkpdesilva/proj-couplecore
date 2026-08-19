import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_paths.dart';

class AlertService {
  AlertService(this._db);

  final FirebaseFirestore _db;

  Future<void> sendEmergencyAlert({
    required String coupleId,
    required String fromUid,
    required String toUid,
    required String message,
  }) {
    return _db
        .collection(FirestorePaths.couples)
        .doc(coupleId)
        .collection(FirestorePaths.alerts)
        .add({
      'from': fromUid,
      'to': toUid,
      'type': 'emergency',
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
