import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/chat_message.dart';
import '../../models/problem_session.dart';
import 'solved_problems_screen.dart';

const _kBackground = Color(0xFFF3E8FF);
const _kBubbleFromPartner = Color(0xFFE8E0F7);

/// FR-47/48: log a problem with your partner and get AI-assisted
/// communication tips as you talk it through, using the couple's own
/// problem-solving history for context.
class ProblemSolverScreen extends ConsumerStatefulWidget {
  const ProblemSolverScreen({super.key});

  @override
  ConsumerState<ProblemSolverScreen> createState() =>
      _ProblemSolverScreenState();
}

class _ProblemSolverScreenState extends ConsumerState<ProblemSolverScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoadingAI = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final couple = ref.watch(myCoupleProvider).valueOrNull;
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      backgroundColor: _kBackground,
      drawer:
          couple != null && couple.isActive
              ? _buildDrawer(context, couple.id, myUid)
              : null,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Problem Solver',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevation: 0,
        actions:
            couple != null && couple.isActive && myUid != null
                ? [_ActiveSessionActions(coupleId: couple.id)]
                : null,
      ),
      body:
          couple == null || !couple.isActive
              ? _buildNotLinkedState()
              : myUid == null
              ? const Center(child: CircularProgressIndicator())
              : _ActiveCoupleBody(
                coupleId: couple.id,
                myUid: myUid,
                messageController: _messageController,
                scrollController: _scrollController,
                isLoadingAI: _isLoadingAI,
                onLoadingChanged: (v) => setState(() => _isLoadingAI = v),
              ),
    );
  }

  Widget _buildDrawer(BuildContext context, String coupleId, String? myUid) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            decoration: const BoxDecoration(color: AppTheme.primary),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.favorite, color: Colors.white, size: 32),
                SizedBox(height: 12),
                Text(
                  'Problem Solver',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Your relationship companion',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(
              Icons.chat_bubble_outline,
              color: AppTheme.primary,
            ),
            title: const Text(
              'Current Problem',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () => Navigator.pop(context),
          ),
          const Divider(indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.check_circle, color: Color(0xFF1BAE5D)),
            title: const Text(
              'Solved Problems',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(context);
              if (myUid == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => SolvedProblemsScreen(
                        coupleId: coupleId,
                        currentUserUid: myUid,
                      ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotLinkedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No partner linked',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Link a partner to use Problem Solver together.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

/// AppBar actions that depend on there being an active session — split out
/// so it can watch [problemSessionsProvider] independently of the Scaffold.
class _ActiveSessionActions extends ConsumerWidget {
  const _ActiveSessionActions({required this.coupleId});

  final String coupleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions =
        ref.watch(problemSessionsProvider(coupleId)).valueOrNull ?? const [];
    final activeSessions = sessions.where((s) => s.isActive);
    final active = activeSessions.isEmpty ? null : activeSessions.first;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (active != null)
          IconButton(
            icon: Icon(
              active.isStarred ? Icons.star : Icons.star_border,
              color: Colors.white,
            ),
            tooltip: active.isStarred ? 'Remove from kept' : 'Keep this chat',
            onPressed: () => _toggleStarred(context, ref, active),
          ),
        if (active != null)
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
            tooltip: 'Mark as Solved',
            onPressed: () => _confirmSolve(context, ref, active),
          ),
        IconButton(
          icon: const Icon(Icons.edit_note, color: Colors.white),
          tooltip: 'New Problem',
          onPressed: () => _confirmNewSession(context, ref, active),
        ),
      ],
    );
  }

  /// Toggles the star that protects this session from newest-5 auto-
  /// eviction. Purely a Firestore write — the icon reflects the new state
  /// live via the same [problemSessionsProvider] stream this widget watches.
  Future<void> _toggleStarred(
    BuildContext context,
    WidgetRef ref,
    ProblemSession active,
  ) async {
    final newValue = !active.isStarred;
    await ref
        .read(problemServiceProvider)
        .setStarred(
          coupleId: coupleId,
          sessionId: active.id,
          starred: newValue,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newValue ? 'Chat kept' : 'No longer kept')),
      );
    }
  }

  Future<void> _confirmNewSession(
    BuildContext context,
    WidgetRef ref,
    ProblemSession? active,
  ) async {
    if (active != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Start New Problem?'),
              content: const Text(
                'The current problem stays active. You can mark it solved anytime.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                  ),
                  child: const Text(
                    'Start New',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
      );
      if (confirm != true) return;
    }
    final myUid = ref.read(authStateProvider).valueOrNull?.uid;
    if (myUid == null) return;
    await ref
        .read(problemServiceProvider)
        .startSession(coupleId: coupleId, createdByUid: myUid);
  }

  /// FR-48 solve flow: extract a structured record via Gemini, let the user
  /// confirm it, save it, and only then delete the raw chat. Any failure
  /// (extraction, save) or a Cancel leaves the session completely untouched
  /// — deletion only ever runs after a confirmed, successful save.
  Future<void> _confirmSolve(
    BuildContext context,
    WidgetRef ref,
    ProblemSession active,
  ) async {
    final problemService = ref.read(problemServiceProvider);
    final messages =
        ref
            .read(
              problemMessagesProvider((
                coupleId: coupleId,
                sessionId: active.id,
              )),
            )
            .valueOrNull ??
        const [];

    final record = await ref
        .read(aiCounselorServiceProvider)
        .extractSolvedRecord(messages);
    if (record == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't summarize this chat — try again once there's a bit more back-and-forth.",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Mark as Solved?'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SolveRecordField(label: 'Problem', value: record.problem),
                  const SizedBox(height: 12),
                  _SolveRecordField(label: 'Solution', value: record.solution),
                  const SizedBox(height: 12),
                  _SolveRecordField(label: 'Impact', value: record.impact),
                  const SizedBox(height: 12),
                  Text(
                    'Confirming saves this summary and removes the chat.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1BAE5D),
                ),
                child: const Text(
                  'Confirm',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await problemService.saveSolvedProblem(
        coupleId: coupleId,
        sourceTitle: active.title,
        problem: record.problem,
        solution: record.solution,
        impact: record.impact,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save — problem left active. ($e)'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await problemService.deleteSession(
      coupleId: coupleId,
      sessionId: active.id,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Problem solved and saved!'),
          backgroundColor: Color(0xFF1BAE5D),
        ),
      );
    }
  }
}

class _SolveRecordField extends StatelessWidget {
  const _SolveRecordField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

class _ActiveCoupleBody extends ConsumerWidget {
  const _ActiveCoupleBody({
    required this.coupleId,
    required this.myUid,
    required this.messageController,
    required this.scrollController,
    required this.isLoadingAI,
    required this.onLoadingChanged,
  });

  final String coupleId;
  final String myUid;
  final TextEditingController messageController;
  final ScrollController scrollController;
  final bool isLoadingAI;
  final ValueChanged<bool> onLoadingChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(problemSessionsProvider(coupleId)).valueOrNull;
    if (sessions == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeSessions = sessions.where((s) => s.isActive);
    final active = activeSessions.isEmpty ? null : activeSessions.first;

    return Column(
      children: [
        Expanded(
          child:
              active == null
                  ? _buildEmptyState(ref)
                  : _ChatArea(
                    coupleId: coupleId,
                    session: active,
                    myUid: myUid,
                    scrollController: scrollController,
                    isLoadingAI: isLoadingAI,
                  ),
        ),
        if (active != null)
          _InputBar(
            coupleId: coupleId,
            session: active,
            myUid: myUid,
            controller: messageController,
            scrollController: scrollController,
            isLoadingAI: isLoadingAI,
            onLoadingChanged: onLoadingChanged,
          ),
      ],
    );
  }

  Widget _buildEmptyState(WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology_alt,
              size: 40,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No active problem',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap below to start sharing a problem\nwith your partner.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed:
                () => ref
                    .read(problemServiceProvider)
                    .startSession(coupleId: coupleId, createdByUid: myUid),
            icon: const Icon(Icons.add),
            label: const Text('Start New Problem'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatArea extends ConsumerWidget {
  const _ChatArea({
    required this.coupleId,
    required this.session,
    required this.myUid,
    required this.scrollController,
    required this.isLoadingAI,
  });

  final String coupleId;
  final ProblemSession session;
  final String myUid;
  final ScrollController scrollController;
  final bool isLoadingAI;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages =
        ref
            .watch(
              problemMessagesProvider((
                coupleId: coupleId,
                sessionId: session.id,
              )),
            )
            .valueOrNull;

    if (messages == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'Type your problem below to get started.',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: messages.length + (isLoadingAI ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) return const _TypingIndicator();
        return _MessageBubble(message: messages[index], myUid: myUid);
      },
    );
  }

  void _scrollToBottom() {
    if (!scrollController.hasClients) return;
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.myUid});

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
                            : (isMe ? AppTheme.primary : _kBubbleFromPartner),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isAI ? 4 : 16),
                      bottomRight: Radius.circular(isMe && !isAI ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
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

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primary,
            child: Icon(Icons.psychology, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(0),
                const SizedBox(width: 5),
                _dot(200),
                const SizedBox(width: 5),
                _dot(400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + delayMs),
      builder:
          (_, value, __) => Opacity(
            opacity: value,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
    );
  }
}

class _InputBar extends ConsumerWidget {
  const _InputBar({
    required this.coupleId,
    required this.session,
    required this.myUid,
    required this.controller,
    required this.scrollController,
    required this.isLoadingAI,
    required this.onLoadingChanged,
  });

  final String coupleId;
  final ProblemSession session;
  final String myUid;
  final TextEditingController controller;
  final ScrollController scrollController;
  final bool isLoadingAI;
  final ValueChanged<bool> onLoadingChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _kBackground,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: controller,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Describe your problem...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: isLoadingAI ? null : () => _sendMessage(context, ref),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child:
                      isLoadingAI
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(BuildContext context, WidgetRef ref) async {
    final text = controller.text.trim();
    if (text.isEmpty || isLoadingAI) return;

    controller.clear();
    onLoadingChanged(true);

    final problemService = ref.read(problemServiceProvider);
    final myName =
        ref.read(firebaseAuthProvider).currentUser?.displayName ?? 'You';

    await problemService.addMessage(
      coupleId: coupleId,
      sessionId: session.id,
      role: 'user',
      content: text,
      senderUid: myUid,
      senderName: myName,
    );

    try {
      final priorMessages =
          ref
              .read(
                problemMessagesProvider((
                  coupleId: coupleId,
                  sessionId: session.id,
                )),
              )
              .valueOrNull ??
          const [];
      final recentSolved = await problemService.fetchRecentSolved(coupleId);

      final aiText = await ref
          .read(aiCounselorServiceProvider)
          .reply(
            message: text,
            priorMessages: priorMessages,
            recentSolved: recentSolved,
          );

      await problemService.addMessage(
        coupleId: coupleId,
        sessionId: session.id,
        role: 'model',
        content: aiText,
        senderName: 'AI Counselor',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      onLoadingChanged(false);
    }
  }
}
