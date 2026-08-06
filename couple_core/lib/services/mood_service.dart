import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_paths.dart';

class MoodService {
  MoodService(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> moodDoc(String coupleId, String uid) => _db
      .collection(FirestorePaths.couples)
      .doc(coupleId)
      .collection(FirestorePaths.moods)
      .doc(uid);

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMood(String coupleId, String uid) =>
      moodDoc(coupleId, uid).snapshots();

  /// Note: updatedAt is written for the server's own bookkeeping only — it
  /// must never be read/displayed client-side (NFR-7, no presence disclosure).
  Future<void> setMood({required String coupleId, required String uid, required String mood}) {
    return moodDoc(coupleId, uid).set({
      'mood': mood,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
