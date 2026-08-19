import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/couple.dart';
import 'firestore_paths.dart';

class CoupleService {
  CoupleService(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> coupleDoc(String coupleId) =>
      _db.collection(FirestorePaths.couples).doc(coupleId);

  /// A user has at most one active/pending couple at a time (FR-13).
  Stream<Couple?> watchMyCouple(String uid) {
    return _db
        .collection(FirestorePaths.couples)
        .where('memberUids', arrayContains: uid)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          final doc = snap.docs.first;
          return Couple.fromMap(doc.id, doc.data());
        });
  }

  /// Completes mutual confirmation (FR-11): flips a pending couple to active.
  Future<void> confirmCouple(String coupleId) {
    return coupleDoc(coupleId).update({'status': 'active'});
  }

  /// Unlink (FR-13, NFR-9): deletes the couple doc and every subcollection
  /// doc so no shared data is orphaned. The other partner's own client clears
  /// its own users/{uid} link fields reactively once it observes the couple
  /// doc is gone (see DashboardScreen) — this method never writes to the
  /// other partner's user doc directly.
  Future<void> deleteCoupleCascade(String coupleId) async {
    final couple = coupleDoc(coupleId);
    for (final sub in [FirestorePaths.moods, FirestorePaths.alerts]) {
      final docs = await couple.collection(sub).get();
      if (docs.docs.isEmpty) continue;
      final batch = _db.batch();
      for (final doc in docs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await _deleteProblemSessions(couple);
    await couple.delete();
  }

  /// problemSessions carry a nested messages/ subcollection, so each
  /// session's messages must be cleared before the session doc itself.
  Future<void> _deleteProblemSessions(
    DocumentReference<Map<String, dynamic>> couple,
  ) async {
    final sessions =
        await couple.collection(FirestorePaths.problemSessions).get();
    for (final session in sessions.docs) {
      final messages =
          await session.reference.collection(FirestorePaths.messages).get();
      if (messages.docs.isNotEmpty) {
        final batch = _db.batch();
        for (final message in messages.docs) {
          batch.delete(message.reference);
        }
        await batch.commit();
      }
      await session.reference.delete();
    }
  }
}
