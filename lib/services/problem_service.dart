import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message.dart';
import '../models/problem_session.dart';
import '../models/solved_problem.dart';
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

  CollectionReference<Map<String, dynamic>> _solvedProblemsRef(
    String coupleId,
  ) => _db
      .collection(FirestorePaths.couples)
      .doc(coupleId)
      .collection(FirestorePaths.solvedProblems);

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

  /// Recently solved problems for this couple — sent to the AI as light
  /// context so tips build on what already worked for them (FR-48), never
  /// full transcripts (NFR-6, minimal context). No status filter needed:
  /// every doc in solvedProblems is, by definition, already solved.
  Future<List<SolvedProblem>> fetchRecentSolved(
    String coupleId, {
    int limit = 5,
  }) async {
    final snap =
        await _solvedProblemsRef(
          coupleId,
        ).orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map((d) => SolvedProblem.fromMap(d.id, d.data())).toList();
  }

  /// All solved-problem records for this couple, newest first.
  Stream<List<SolvedProblem>> watchSolvedProblems(String coupleId) {
    return _solvedProblemsRef(coupleId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((d) => SolvedProblem.fromMap(d.id, d.data()))
                  .toList(),
        );
  }

  /// FR-48 solve flow: persists the AI-extracted record. Call only after the
  /// user has confirmed it and BEFORE deleting the source session — the
  /// caller must not delete the raw chat unless this succeeds.
  Future<void> saveSolvedProblem({
    required String coupleId,
    required String sourceTitle,
    required String problem,
    required String solution,
    required String impact,
  }) {
    return _solvedProblemsRef(coupleId).add({
      'sourceTitle': sourceTitle,
      'problem': problem,
      'solution': solution,
      'impact': impact,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Superseded by the extract/confirm/save/delete solve flow (which deletes
  /// the session instead of marking it solved in place) — left for any
  /// pre-existing sessions that already have status 'solved' from before.
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
