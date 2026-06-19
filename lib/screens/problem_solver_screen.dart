import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../constants/app_constants.dart';
import 'solved_problems_screen.dart';

class ProblemSolverScreen extends StatefulWidget {
  final User user;
  const ProblemSolverScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ProblemSolverScreen> createState() => _ProblemSolverScreenState();
}

class _ProblemSolverScreenState extends State<ProblemSolverScreen> {
  final _db = FirebaseFirestore.instance;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  String? _coupleId;
  String? _partnerUid;
  String _userName = '';
  String? _currentSessionId;
  bool _isLoadingAI = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final doc = await _db.collection('users').doc(widget.user.uid).get();
    final data = doc.data();
    if (!mounted) return;
    setState(() {
      _coupleId = data?['coupleId'] as String?;
      _partnerUid = data?['partnerUid'] as String?;
      _userName = (data?['name'] as String?) ??
          (widget.user.displayName ?? 'You');
      _isInitializing = false;
    });
    if (_coupleId != null) await _loadActiveSession();
  }

  Future<void> _loadActiveSession() async {
    final query = await _db
        .collection('problem_sessions')
        .where('coupleId', isEqualTo: _coupleId)
        .where('status', isEqualTo: 'active')
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty && mounted) {
      setState(() => _currentSessionId = query.docs.first.id);
    }
  }

  Future<void> _startNewSession() async {
    if (_coupleId == null) return;
    final now = DateTime.now();
    final ref = _db.collection('problem_sessions').doc();
    await ref.set({
      'title': 'Problem ${now.day}/${now.month}/${now.year}',
      'coupleId': _coupleId,
      'partnerUids': [widget.user.uid, _partnerUid],
      'status': 'active',
      'createdBy': widget.user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
    });
    if (mounted) setState(() => _currentSessionId = ref.id);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentSessionId == null || _isLoadingAI) return;

    _messageController.clear();
    setState(() => _isLoadingAI = true);

    final messagesRef = _db
        .collection('problem_sessions')
        .doc(_currentSessionId)
        .collection('messages');

    await messagesRef.add({
      'role': 'user',
      'content': text,
      'senderUid': widget.user.uid,
      'senderName': _userName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db
        .collection('problem_sessions')
        .doc(_currentSessionId)
        .update({'updatedAt': FieldValue.serverTimestamp(), 'lastMessage': text});

    _scrollToBottom();

    try {
      // Build chat history from existing messages
      final msgSnap = await messagesRef.orderBy('createdAt').get();
      final history = <Content>[];
      for (final doc in msgSnap.docs.take(msgSnap.docs.length - 1)) {
        final d = doc.data();
        final role = d['role'] as String;
        final content = d['content'] as String;
        history.add(
          role == 'user'
              ? Content.text(content)
              : Content.model([TextPart(content)]),
        );
      }

      // Build context from past solved problems
      final solvedSnap = await _db
          .collection('problem_sessions')
          .where('coupleId', isEqualTo: _coupleId)
          .where('status', isEqualTo: 'solved')
          .orderBy('updatedAt', descending: true)
          .limit(5)
          .get();

      String pastContext = '';
      if (solvedSnap.docs.isNotEmpty) {
        pastContext =
            '\n\nPrevious solved problems from this couple (use for context to give personalised advice):\n';
        for (final s in solvedSnap.docs) {
          final sd = s.data();
          pastContext +=
              '- ${sd['title']}: ${sd['lastMessage'] ?? ''}\n';
        }
      }

      final systemInstruction = '''You are a compassionate relationship counselor AI helping a couple work through their problems together.
Both partners share this conversation — give balanced, empathetic advice that considers both perspectives equally.
Be practical, concise, and constructive. Avoid taking sides.
Draw on the couple\'s previous solved problems to give more personalised guidance.$pastContext''';

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: kGeminiApiKey,
        systemInstruction: Content.system(systemInstruction),
      );

      final chat = model.startChat(history: history);
      final response = await chat.sendMessage(Content.text(text));
      final aiText =
          response.text ?? 'Unable to generate a response. Please try again.';

      await messagesRef.add({
        'role': 'model',
        'content': aiText,
        'senderUid': null,
        'senderName': 'AI Counselor',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingAI = false);
    }
  }

  Future<void> _markSolved() async {
    if (_currentSessionId == null) return;
    await _db.collection('problem_sessions').doc(_currentSessionId).update({
      'status': 'solved',
      'solvedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) setState(() => _currentSessionId = null);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E8FF),
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B7FD8),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Problem Solver',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevation: 0,
        actions: [
          if (_currentSessionId != null)
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              tooltip: 'Mark as Solved',
              onPressed: _confirmMarkSolved,
            ),
          IconButton(
            icon: const Icon(Icons.edit_note, color: Colors.white),
            tooltip: 'New Problem',
            onPressed: _confirmNewSession,
          ),
        ],
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : _coupleId == null
              ? _buildNotLinkedState()
              : Column(
                  children: [
                    Expanded(child: _buildChatArea()),
                    _buildInputBar(),
                  ],
                ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            decoration: const BoxDecoration(color: Color(0xFF8B7FD8)),
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
            leading:
                const Icon(Icons.chat_bubble_outline, color: Color(0xFF8B7FD8)),
            title: const Text(
              'Current Problem',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () => Navigator.pop(context),
          ),
          const Divider(indent: 16, endIndent: 16),
          ListTile(
            leading:
                const Icon(Icons.check_circle, color: Color(0xFF1BAE5D)),
            title: const Text(
              'Solved Problems',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(context);
              if (_coupleId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SolvedProblemsScreen(
                      coupleId: _coupleId!,
                      currentUserUid: widget.user.uid,
                    ),
                  ),
                );
              }
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
              'Link a partner in Settings to use Problem Solver together.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    if (_currentSessionId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF8B7FD8).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology_alt,
                size: 40,
                color: Color(0xFF8B7FD8),
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
              onPressed: _startNewSession,
              icon: const Icon(Icons.add),
              label: const Text('Start New Problem'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B7FD8),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('problem_sessions')
          .doc(_currentSessionId)
          .collection('messages')
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final messages = snapshot.data!.docs;
        if (messages.isEmpty) {
          return Center(
            child: Text(
              'Type your problem below to get started.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          itemCount: messages.length + (_isLoadingAI ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == messages.length) return _buildTypingIndicator();
            final data = messages[index].data() as Map<String, dynamic>;
            return _buildMessageBubble(data);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data) {
    final isAI = data['role'] == 'model';
    final isMe = data['senderUid'] == widget.user.uid;
    final content = data['content'] as String? ?? '';
    final senderName = data['senderName'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isAI
            ? MainAxisAlignment.start
            : isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
        children: [
          if (isAI) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF8B7FD8),
              child: Icon(Icons.psychology, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isAI || !isMe
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                if (isAI || !isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(
                      isAI ? 'AI Counselor' : senderName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isAI
                        ? Colors.white
                        : isMe
                            ? const Color(0xFF8B7FD8)
                            : const Color(0xFFE8E0F7),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isAI ? 4 : 16),
                      bottomRight:
                          Radius.circular(isMe && !isAI ? 4 : 16),
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
                    content,
                    style: TextStyle(
                      color: isAI || !isMe
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

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF8B7FD8),
            child: Icon(Icons.psychology, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _animatedDot(0),
                const SizedBox(width: 5),
                _animatedDot(200),
                const SizedBox(width: 5),
                _animatedDot(400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _animatedDot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + delayMs),
      builder: (_, value, __) => Opacity(
        opacity: value,
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF8B7FD8),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
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
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Describe your problem...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: const Color(0xFF8B7FD8),
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _isLoadingAI ? null : _sendMessage,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: _isLoadingAI
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send,
                          color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmNewSession() async {
    if (_currentSessionId != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  backgroundColor: const Color(0xFF8B7FD8)),
              child: const Text('Start New',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    await _startNewSession();
  }

  Future<void> _confirmMarkSolved() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as Solved?'),
        content: const Text(
          'This moves the problem to your Solved Problems history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1BAE5D)),
            child: const Text('Mark Solved',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) await _markSolved();
  }
}
