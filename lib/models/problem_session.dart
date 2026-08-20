import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors couples/{coupleId}/problemSessions/{id} — an AI-assisted
/// conversation the couple has about a problem, from first message through
/// resolution (FR-47/48).
class ProblemSession {
  const ProblemSession({
    required this.id,
    required this.title,
    required this.status,
    required this.createdByUid,
    this.lastMessage = '',
    this.solvedAt,
    this.problemSummary,
    this.solution,
    this.tags = const [],
  });

  final String id;
  final String title;

  /// active | solved
  final String status;
  final String createdByUid;
  final String lastMessage;
  final Timestamp? solvedAt;

  /// AI-generated on solve (FR-48) — null for sessions solved before this
  /// existed, or where the summarize call failed. Always present as a pair:
  /// see [AiCounselorService.summarize].
  final String? problemSummary;
  final String? solution;
  final List<String> tags;

  bool get isActive => status == 'active';
  bool get isSolved => status == 'solved';

  factory ProblemSession.fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) {
      return ProblemSession(
        id: id,
        title: '',
        status: 'active',
        createdByUid: '',
      );
    }
    return ProblemSession(
      id: id,
      title: data['title'] as String? ?? 'Untitled Problem',
      status: data['status'] as String? ?? 'active',
      createdByUid: data['createdByUid'] as String? ?? '',
      lastMessage: data['lastMessage'] as String? ?? '',
      solvedAt: data['solvedAt'] as Timestamp?,
      problemSummary: data['problemSummary'] as String?,
      solution: data['solution'] as String?,
      tags: (data['tags'] as List?)?.cast<String>() ?? const [],
    );
  }
}
