import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/problem_session.dart';
import 'problem_solver_screen.dart';

/// FR-47/48: a ChatGPT-style list of this couple's surviving raw
/// problem-solving sessions (display only — no delete, no status change).
/// Reuses [problemSessionsProvider]/watchSessions, the same stream the main
/// Problem Solver screen already watches — no new Firestore query. Excludes
/// solved sessions defensively, though in practice none should ever be
/// found here: the Solve flow deletes a session's raw doc outright as soon
/// as it's saved to solvedProblems.
class ChatsListScreen extends ConsumerWidget {
  const ChatsListScreen({super.key, required this.coupleId});

  final String coupleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(problemSessionsProvider(coupleId)).valueOrNull;
    final chats = sessions?.where((s) => !s.isSolved).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3E8FF),
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevation: 0,
      ),
      body:
          chats == null
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(chats),
    );
  }

  Widget _buildBody(List<ProblemSession> chats) {
    if (chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No chats yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a problem to see it here.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: chats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _ChatRow(session: chats[index]),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.session});

  final ProblemSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEDE7F6),
          child: Icon(Icons.chat_bubble_outline, color: AppTheme.primary),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                session.title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            if (session.isStarred) ...[
              const SizedBox(width: 6),
              const Icon(Icons.star, size: 16, color: Color(0xFFF5B301)),
            ],
          ],
        ),
        subtitle:
            session.lastMessage.isEmpty
                ? null
                : Text(
                  session.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => ProblemSolverScreen(initialSessionId: session.id),
              ),
            ),
      ),
    );
  }
}
