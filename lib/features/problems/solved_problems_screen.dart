import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/solved_problem.dart';

/// FR-48: solved problems are structured records (problem/solution/impact) —
/// the raw chat they were extracted from is deleted once solved, so there's
/// no transcript to show here, just the summary.
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
    final solved = ref.watch(solvedProblemsProvider(coupleId)).valueOrNull;

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
          solved == null
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(context, solved),
    );
  }

  Widget _buildBody(BuildContext context, List<SolvedProblem> solved) {
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
              'Solve a problem to see it here.',
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
          (context, index) => _SolvedProblemCard(problem: solved[index]),
    );
  }
}

class _SolvedProblemCard extends StatelessWidget {
  const _SolvedProblemCard({required this.problem});

  final SolvedProblem problem;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        problem.createdAt != null
            ? DateFormat('MMM d, yyyy').format(problem.createdAt!.toDate())
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
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE8F5E9),
          child: Icon(Icons.check_circle, color: Color(0xFF1BAE5D)),
        ),
        title: Text(
          problem.sourceTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              problem.problem,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
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
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SolvedProblemDetailScreen(problem: problem),
              ),
            ),
      ),
    );
  }
}

class SolvedProblemDetailScreen extends StatelessWidget {
  const SolvedProblemDetailScreen({super.key, required this.problem});

  final SolvedProblem problem;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E8FF),
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          problem.sourceTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _DetailSection(label: 'Problem', text: problem.problem),
          const SizedBox(height: 20),
          _DetailSection(label: 'Solution', text: problem.solution),
          const SizedBox(height: 20),
          _DetailSection(label: 'Impact', text: problem.impact),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF2C2C2C),
            ),
          ),
        ),
      ],
    );
  }
}
