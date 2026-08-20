import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../core/secrets.dart';
import '../models/chat_message.dart';
import '../models/problem_session.dart';

/// The structured record [AiCounselorService.summarize] produces for a
/// solved problem — deliberately just a couple of sentences plus tags, never
/// the full transcript (NFR-6, minimal context).
typedef ProblemSummary =
    ({String problemSummary, String solution, List<String> tags});

/// FR-48: sends the couple's problem context to Gemini and returns tailored
/// communication tips / calming steps.
///
/// Known gap (tracked as a follow-up, not fixed by this port): this calls
/// the Gemini API directly from the client using [kGeminiApiKey], not via a
/// server-side Cloud Function proxy. NFR-6 calls for the key to live
/// server-side only — see lib/core/secrets.example.dart for local setup in
/// the meantime.
class AiCounselorService {
  const AiCounselorService();

  static const _modelName = 'gemini-3.6-flash';

  static const _systemPreamble =
      'You are a compassionate relationship counselor AI helping a couple '
      'work through their problems together. Both partners share this '
      'conversation — give balanced, empathetic advice that considers both '
      'perspectives equally. Be practical, concise, and constructive. Avoid '
      'taking sides. Draw on the couple\'s previous solved problems to give '
      'more personalised guidance.';

  Future<String> reply({
    required String message,
    required List<ChatMessage> priorMessages,
    required List<ProblemSession> recentSolved,
  }) async {
    final history =
        priorMessages
            .map(
              (m) =>
                  m.isFromAi
                      ? Content.model([TextPart(m.content)])
                      : Content.text(m.content),
            )
            .toList();

    final model = GenerativeModel(
      model: _modelName,
      apiKey: kGeminiApiKey,
      systemInstruction: Content.system(
        '$_systemPreamble${_pastContext(recentSolved)}',
      ),
    );

    final chat = model.startChat(history: history);
    final response = await chat.sendMessage(Content.text(message));
    return response.text ?? 'Unable to generate a response. Please try again.';
  }

  /// FR-48: on "Mark Solved", produce a short structured record from the
  /// session's messages. Returns null on any failure (bad/missing JSON,
  /// network error, empty fields) — callers fall back to title/lastMessage
  /// rather than block the solve.
  Future<ProblemSummary?> summarize(List<ChatMessage> messages) async {
    final transcript = messages
        .map(
          (m) =>
              '${m.isFromAi ? 'Counselor' : (m.senderName.isEmpty ? 'Partner' : m.senderName)}: ${m.content}',
        )
        .join('\n');

    final model = GenerativeModel(model: _modelName, apiKey: kGeminiApiKey);
    final prompt = '''
Summarize this couple's problem-solving conversation. Respond with strict
JSON only — no markdown fences, no commentary, nothing outside the object —
matching exactly this shape:
{"problemSummary": "...", "solution": "...", "tags": ["...", "..."]}

- problemSummary: one or two sentences describing the problem.
- solution: one or two sentences describing how it was resolved or what was
  agreed, based only on what is in the conversation below.
- tags: 1-4 short lowercase keywords (e.g. "communication", "trust", "chores").

Conversation:
$transcript
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text;
      if (text == null) return null;

      final jsonText = _extractJsonObject(text);
      if (jsonText == null) return null;

      final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
      final problemSummary = decoded['problemSummary'] as String?;
      final solution = decoded['solution'] as String?;
      final tags =
          (decoded['tags'] as List?)?.map((t) => t.toString()).toList() ??
          const <String>[];

      if (problemSummary == null ||
          problemSummary.isEmpty ||
          solution == null ||
          solution.isEmpty) {
        return null;
      }
      return (problemSummary: problemSummary, solution: solution, tags: tags);
    } catch (_) {
      return null;
    }
  }

  /// Gemini sometimes wraps JSON in markdown fences despite instructions —
  /// slice out the outermost {...} rather than trying to strip fences.
  String? _extractJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end < start) return null;
    return text.substring(start, end + 1);
  }

  String _pastContext(List<ProblemSession> recentSolved) {
    if (recentSolved.isEmpty) return '';
    final lines = recentSolved
        .map(
          (s) =>
              s.problemSummary != null && s.solution != null
                  ? '- ${s.problemSummary} Resolved by: ${s.solution}'
                  : '- ${s.title}: ${s.lastMessage}',
        )
        .join('\n');
    return '\n\nPrevious solved problems from this couple (use for context '
        'to give personalised advice):\n$lines';
  }
}
