import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message.dart';
import '../models/problem_session.dart';
import 'firestore_paths.dart';

/// FR-47/48: AI-assisted problem-solving sessions, scoped per couple.
class ProblemService {
  ProblemService(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _sessionsRef(String coupleId) => _db
      .collection(FirestorePaths.couples)
      .doc(coupleId)
      .collection(FirestorePaths.problemSessions);

  DocumentReference<Map<String, dynamic>> sessionDoc(
    String coupleId,
    String sessionId,
  ) => _sessionsRef(coupleId).doc(sessionId);

  CollectionReference<Map<String, dynamic>> _messagesRef(
    String coupleId,
    String sessionId,
  ) => sessionDoc(coupleId, sessionId).collection(FirestorePaths.messages);

  /// All sessions, newest-updated first. Providers/UI split this into the
  /// active session and the solved history client-side — per-couple session
  /// counts are small enough that this avoids a composite Firestore index
  /// for a status-filtered query.
  Stream<List<ProblemSession>> watchSessions(String coupleId) {
    return _sessionsRef(coupleId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((d) => ProblemSession.fromMap(d.id, d.data()))
                  .toList(),
        );
  }

  Stream<List<ChatMessage>> watchMessages(String coupleId, String sessionId) {
    return _messagesRef(coupleId, sessionId)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((d) => ChatMessage.fromMap(d.id, d.data()))
                  .toList(),
        );
  }

  Future<String> startSession({
    required String coupleId,
    required String createdByUid,
  }) async {
    final now = DateTime.now();
    final ref = _sessionsRef(coupleId).doc();
    await ref.set({
      'title': 'Problem ${now.day}/${now.month}/${now.year}',
      'status': 'active',
      'createdByUid': createdByUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
    });
    return ref.id;
  }

  Future<void> addMessage({
    required String coupleId,
    required String sessionId,
    required String role,
    required String content,
    String? senderUid,
    String senderName = '',
  }) async {
    await _messagesRef(coupleId, sessionId).add({
      'role': role,
      'content': content,
      'senderUid': senderUid,
      'senderName': senderName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await sessionDoc(coupleId, sessionId).update({
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': content,
    });
  }

  /// Recently solved sessions for this couple — sent to the AI as light
  /// context so tips build on what already worked for them (FR-48), never
  /// full transcripts (NFR-6, minimal context). Filters client-side from a
  /// plain orderBy query for the same index-free reason as [watchSessions].
  Future<List<ProblemSession>> fetchRecentSolved(
    String coupleId, {
    int limit = 5,
  }) async {
    final snap =
        await _sessionsRef(
          coupleId,
        ).orderBy('updatedAt', descending: true).get();
    return snap.docs
        .map((d) => ProblemSession.fromMap(d.id, d.data()))
        .where((s) => s.isSolved)
        .take(limit)
        .toList();
  }

  /// [problemSummary]/[solution]/[tags] are the AI-generated record from
  /// [AiCounselorService.summarize] — optional, since summarization is
  /// skipped for short sessions or can fail without blocking the solve.
  Future<void> markSolved({
    required String coupleId,
    required String sessionId,
    String? problemSummary,
    String? solution,
    List<String>? tags,
  }) {
    final updates = <String, dynamic>{
      'status': 'solved',
      'solvedAt': FieldValue.serverTimestamp(),
    };
    if (problemSummary != null) updates['problemSummary'] = problemSummary;
    if (solution != null) updates['solution'] = solution;
    if (tags != null) updates['tags'] = tags;
    return sessionDoc(coupleId, sessionId).update(updates);
  }

  Future<void> unmarkSolved({
    required String coupleId,
    required String sessionId,
  }) {
    return sessionDoc(
      coupleId,
      sessionId,
    ).update({'status': 'active', 'solvedAt': FieldValue.delete()});
  }

  Future<void> updateTitle({
    required String coupleId,
    required String sessionId,
    required String title,
  }) {
    return sessionDoc(coupleId, sessionId).update({'title': title});
  }

  Future<void> deleteSession({
    required String coupleId,
    required String sessionId,
  }) async {
    final messages = await _messagesRef(coupleId, sessionId).get();
    if (messages.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await sessionDoc(coupleId, sessionId).delete();
  }
}
