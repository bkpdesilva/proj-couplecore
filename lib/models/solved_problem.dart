import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors couples/{coupleId}/solvedProblems/{id} — the structured record
/// extracted by Gemini when a problem-solving session is solved (FR-48). The
/// raw chat it was extracted from is deleted once this record is saved; this
/// is the only surviving trace of that conversation.
class SolvedProblem {
  const SolvedProblem({
    required this.id,
    required this.sourceTitle,
    required this.problem,
    required this.solution,
    required this.impact,
    this.createdAt,
  });

  final String id;
  final String sourceTitle;
  final String problem;
  final String solution;
  final String impact;
  final Timestamp? createdAt;

  factory SolvedProblem.fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) {
      return SolvedProblem(
        id: id,
        sourceTitle: '',
        problem: '',
        solution: '',
        impact: '',
      );
    }
    return SolvedProblem(
      id: id,
      sourceTitle: data['sourceTitle'] as String? ?? '',
      problem: data['problem'] as String? ?? '',
      solution: data['solution'] as String? ?? '',
      impact: data['impact'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}
