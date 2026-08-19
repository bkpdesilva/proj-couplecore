import 'package:flutter/material.dart';

import '../../problems/problem_solver_screen.dart';

class FeatureGrid extends StatelessWidget {
  const FeatureGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.1,
        children: [
          const _FeatureCard(
            title: 'Shared Calendar',
            icon: Icons.calendar_today,
            bgColor: Color(0xFFFFEBEE),
            iconColor: Color(0xFFE91E63),
          ),
          const _FeatureCard(
            title: 'Memories',
            icon: Icons.photo_album,
            bgColor: Color(0xFFFFF3E0),
            iconColor: Color(0xFFFF9800),
          ),
          const _FeatureCard(
            title: 'Messages',
            icon: Icons.chat_bubble,
            bgColor: Color(0xFFE8F5E9),
            iconColor: Color(0xFF4CAF50),
          ),
          const _FeatureCard(
            title: 'Good Deeds',
            icon: Icons.star,
            bgColor: Color(0xFFF3E5F5),
            iconColor: Color(0xFF9C27B0),
          ),
          _FeatureCard(
            title: 'Problem Solver',
            icon: Icons.psychology_alt,
            bgColor: const Color(0xFFEDE7F6),
            iconColor: const Color(0xFF8B7FD8),
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProblemSolverScreen(),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          onTap ??
          () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Opening $title...'))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C2C2C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
