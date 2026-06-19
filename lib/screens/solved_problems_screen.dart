import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SolvedProblemsScreen extends StatelessWidget {
  final String coupleId;
  final String currentUserUid;

  const SolvedProblemsScreen({
    Key? key,
    required this.coupleId,
    required this.currentUserUid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: const Color(0xFFF3E8FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B7FD8),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Solved Problems',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db
            .collection('problem_sessions')
            .where('coupleId', isEqualTo: coupleId)
            .where('status', isEqualTo: 'solved')
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 64, color: Color(0xFF1BAE5D)),
                  const SizedBox(height: 16),
                  const Text(
                    'No solved problems yet',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
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
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _ProblemCard(
                docId: doc.id,
                data: data,
                db: db,
                currentUserUid: currentUserUid,
                coupleId: coupleId,
              );
            },
          );
        },
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final FirebaseFirestore db;
  final String currentUserUid;
  final String coupleId;

  const _ProblemCard({
    required this.docId,
    required this.data,
    required this.db,
    required this.currentUserUid,
    required this.coupleId,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'Untitled Problem';
    final lastMessage = data['lastMessage'] as String? ?? '';
    final solvedAt = data['solvedAt'] as Timestamp?;
    final dateStr = solvedAt != null
        ? DateFormat('MMM d, yyyy').format(solvedAt.toDate())
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
          title,
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lastMessage.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                lastMessage,
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
          onSelected: (value) =>
              _handleAction(context, value, title),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(children: [
                Icon(Icons.visibility_outlined, size: 18),
                SizedBox(width: 8),
                Text('View'),
              ]),
            ),
            const PopupMenuItem(
              value: 'unmark',
              child: Row(children: [
                Icon(Icons.refresh, size: 18, color: Colors.orange),
                SizedBox(width: 8),
                Text('Unmark Solved'),
              ]),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline, size: 18, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete',
                    style: TextStyle(color: Colors.red)),
              ]),
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProblemDetailScreen(
              sessionId: docId,
              title: title,
              currentUserUid: currentUserUid,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(
      BuildContext context, String action, String title) async {
    switch (action) {
      case 'view':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProblemDetailScreen(
              sessionId: docId,
              title: title,
              currentUserUid: currentUserUid,
            ),
          ),
        );
        break;

      case 'unmark':
        await db.collection('problem_sessions').doc(docId).update({
          'status': 'active',
          'solvedAt': FieldValue.delete(),
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Problem moved back to active')),
          );
        }
        break;

      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete Problem?'),
            content: const Text(
                'This permanently deletes the problem and all messages.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red),
                child: const Text('Delete',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          final msgSnap = await db
              .collection('problem_sessions')
              .doc(docId)
              .collection('messages')
              .get();
          for (final msg in msgSnap.docs) {
            await msg.reference.delete();
          }
          await db.collection('problem_sessions').doc(docId).delete();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Problem deleted')),
            );
          }
        }
        break;
    }
  }
}

class ProblemDetailScreen extends StatefulWidget {
  final String sessionId;
  final String title;
  final String currentUserUid;

  const ProblemDetailScreen({
    Key? key,
    required this.sessionId,
    required this.title,
    required this.currentUserUid,
  }) : super(key: key);

  @override
  State<ProblemDetailScreen> createState() => _ProblemDetailScreenState();
}

class _ProblemDetailScreenState extends State<ProblemDetailScreen> {
  final _db = FirebaseFirestore.instance;
  late String _title;

  @override
  void initState() {
    super.initState();
    _title = widget.title;
  }

  Future<void> _editTitle() async {
    final controller = TextEditingController(text: _title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Title'),
        content: TextField(
          controller: controller,
          decoration:
              const InputDecoration(labelText: 'Problem title'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B7FD8)),
            child: const Text('Save',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty) {
      await _db
          .collection('problem_sessions')
          .doc(widget.sessionId)
          .update({'title': newTitle});
      if (mounted) setState(() => _title = newTitle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E8FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B7FD8),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _title,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('problem_sessions')
            .doc(widget.sessionId)
            .collection('messages')
            .orderBy('createdAt')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final messages = snapshot.data!.docs;
          if (messages.isEmpty) {
            return const Center(child: Text('No messages in this session.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final data =
                  messages[index].data() as Map<String, dynamic>;
              return _buildBubble(data);
            },
          );
        },
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> data) {
    final isAI = data['role'] == 'model';
    final isMe = data['senderUid'] == widget.currentUserUid;
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
                    padding:
                        const EdgeInsets.only(bottom: 4, left: 4),
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
                        color: Colors.black.withValues(alpha: 0.04),
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
}
