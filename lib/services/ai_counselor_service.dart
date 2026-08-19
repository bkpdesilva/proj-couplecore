import 'package:google_generative_ai/google_generative_ai.dart';

import '../core/secrets.dart';
import '../models/chat_message.dart';
import '../models/problem_session.dart';

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
      model: 'gemini-3.6-flash',
      apiKey: kGeminiApiKey,
      systemInstruction: Content.system(
        '$_systemPreamble${_pastContext(recentSolved)}',
      ),
    );

    final chat = model.startChat(history: history);
    final response = await chat.sendMessage(Content.text(message));
    return response.text ?? 'Unable to generate a response. Please try again.';
  }

  String _pastContext(List<ProblemSession> recentSolved) {
    if (recentSolved.isEmpty) return '';
    final lines = recentSolved
        .map((s) => '- ${s.title}: ${s.lastMessage}')
        .join('\n');
    return '\n\nPrevious solved problems from this couple (use for context '
        'to give personalised advice):\n$lines';
  }
}
