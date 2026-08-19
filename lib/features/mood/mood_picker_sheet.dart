import 'package:flutter/material.dart';

class MoodPickerSheet extends StatelessWidget {
  const MoodPickerSheet({super.key, required this.onMoodSelected});

  final ValueChanged<String> onMoodSelected;

  static const _moods = [
    (emoji: '😊', label: 'Happy'),
    (emoji: '😐', label: 'Neutral'),
    (emoji: '😔', label: 'Sad'),
    (emoji: '😰', label: 'Stressed'),
    (emoji: '😍', label: 'Loved'),
    (emoji: '😤', label: 'Frustrated'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'How are you feeling?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final mood in _moods)
                _MoodOption(
                  emoji: mood.emoji,
                  label: mood.label,
                  onTap: () => onMoodSelected(mood.label.toLowerCase()),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MoodOption extends StatelessWidget {
  const _MoodOption({required this.emoji, required this.label, required this.onTap});

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }
}
