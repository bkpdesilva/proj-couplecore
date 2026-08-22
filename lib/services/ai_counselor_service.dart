import 'package:cloud_functions/cloud_functions.dart';

/// The structured record [AiCounselorService.extractSolvedRecord] produces
/// when a problem is solved — persisted to solvedProblems, then the raw chat
/// is deleted, so this (plus [sourceTitle]) is all that survives (NFR-6).
typedef SolvedRecord = ({String problem, String solution, String impact});

class AiCounselorService {
  const AiCounselorService();

  /// FR-48: on Solve, extract a structured problem/solution/impact record
  /// from the session's messages. Returns null on any failure (bad/missing
  /// JSON, network error, empty fields) — the caller must show an error and
  /// leave the chat untouched rather than save a blank record or delete it.
  Future<SolvedRecord?> extractSolvedRecord({
    required String coupleId,
    required String sessionId,
  }) async {
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('solveProblemSummary')
          .call({'coupleId': coupleId, 'sessionId': sessionId});
      final data = Map<String, dynamic>.from(result.data as Map);
      final problem = data['problem'] as String?;
      final solution = data['solution'] as String?;
      final impact = data['impact'] as String?;
      if (problem == null ||
          problem.isEmpty ||
          solution == null ||
          solution.isEmpty ||
          impact == null ||
          impact.isEmpty)
        return null;
      return (problem: problem, solution: solution, impact: impact);
    } catch (_) {
      return null;
    }
  }
}
