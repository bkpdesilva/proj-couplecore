import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/chat_message.dart';
import '../../models/problem_session.dart';

class SolvedProblemsScreen extends ConsumerWidget {
  const SolvedProblemsScreen({
    super.key,
    required this.coupleId,
    required this.currentUserUid,
  });

  final String coupleId;
  final String currentUserUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(problemSessionsProvider(coupleId)).valueOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFFF3E8FF),
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Solved Problems',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevation: 0,
      ),
      body:
          sessions == null
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(
                context,
                ref,
                sessions.where((s) => s.isSolved).toList(),
              ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<ProblemSession> solved,
  ) {
    if (solved.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Color(0xFF1BAE5D),
            ),
            const SizedBox(height: 16),
            const Text(
              'No solved problems yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Mark a problem as solved to see it here.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: solved.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder:
          (context, index) => _ProblemCard(
            coupleId: coupleId,
            session: solved[index],
            currentUserUid: currentUserUid,
          ),
    );
  }
}

class _ProblemCard extends ConsumerWidget {
  const _ProblemCard({
    required this.coupleId,
    required this.session,
    required this.currentUserUid,
  });

  final String coupleId;
  final ProblemSession session;
  final String currentUserUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr =
        session.solvedAt != null
            ? DateFormat('MMM d, yyyy').format(session.solvedAt!.toDate())
            : '';

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
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE8F5E9),
          child: Icon(Icons.check_circle, color: Color(0xFF1BAE5D)),
        ),
        title: Text(
          session.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (session.lastMessage.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                session.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
            if (dateStr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Solved $dateStr',
                style: const TextStyle(
                  color: Color(0xFF1BAE5D),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleAction(context, ref, value),
          itemBuilder:
              (_) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('View'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'unmark',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Unmark Solved'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
        ),
        onTap: () => _openDetail(context),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ProblemDetailScreen(
              coupleId: coupleId,
              session: session,
              currentUserUid: currentUserUid,
            ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final problemService = ref.read(problemServiceProvider);
    switch (action) {
      case 'view':
        _openDetail(context);
        break;

      case 'unmark':
        await problemService.unmarkSolved(
          coupleId: coupleId,
          sessionId: session.id,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Problem moved back to active')),
          );
        }
        break;

      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text('Delete Problem?'),
                content: const Text(
                  'This permanently deletes the problem and all messages.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
        );
        if (confirm == true) {
          await problemService.deleteSession(
            coupleId: coupleId,
            sessionId: session.id,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Problem deleted')));
          }
        }
        break;
    }
  }
}

class ProblemDetailScreen extends ConsumerStatefulWidget {
  const ProblemDetailScreen({
    super.key,
    required this.coupleId,
    required this.session,
    required this.currentUserUid,
  });

  final String coupleId;
  final ProblemSession session;
  final String currentUserUid;

  @override
  ConsumerState<ProblemDetailScreen> createState() =>
      _ProblemDetailScreenState();
}

class _ProblemDetailScreenState extends ConsumerState<ProblemDetailScreen> {
  late String _title;

  @override
  void initState() {
    super.initState();
    _title = widget.session.title;
  }

  Future<void> _editTitle() async {
    final controller = TextEditingController(text: _title);
    final newTitle = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Edit Title'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Problem title'),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
    if (newTitle != null && newTitle.isNotEmpty) {
      await ref
          .read(problemServiceProvider)
          .updateTitle(
            coupleId: widget.coupleId,
            sessionId: widget.session.id,
            title: newTitle,
          );
      if (mounted) setState(() => _title = newTitle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages =
        ref
            .watch(
              problemMessagesProvider((
                coupleId: widget.coupleId,
                sessionId: widget.session.id,
              )),
            )
            .valueOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFFF3E8FF),
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Edit title',
            onPressed: _editTitle,
          ),
        ],
      ),
      body:
          messages == null
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
              ? const Center(child: Text('No messages in this session.'))
              : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: messages.length,
                itemBuilder:
                    (context, index) => _DetailBubble(
                      message: messages[index],
                      myUid: widget.currentUserUid,
                    ),
              ),
    );
  }
}

class _DetailBubble extends StatelessWidget {
  const _DetailBubble({required this.message, required this.myUid});

  final ChatMessage message;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    final isAI = message.isFromAi;
    final isMe = message.senderUid == myUid;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isAI
                ? MainAxisAlignment.start
                : (isMe ? MainAxisAlignment.end : MainAxisAlignment.start),
        children: [
          if (isAI) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary,
              child: Icon(Icons.psychology, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isAI || !isMe
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
              children: [
                if (isAI || !isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(
                      isAI ? 'AI Counselor' : message.senderName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isAI
                            ? Colors.white
                            : (isMe
                                ? AppTheme.primary
                                : const Color(0xFFE8E0F7)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isAI ? 4 : 16),
                      bottomRight: Radius.circular(isMe && !isAI ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color:
                          isAI || !isMe
                              ? const Color(0xFF2C2C2C)
                              : Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
