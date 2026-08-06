import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// FR-5 (notification prefs + quiet hours), FR-13/NFR-9 (unlink + cleanup).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: profileAsync.when(
        data: (profile) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text('Mood reminders'),
              value: profile.notifPrefs.moodReminders,
              onChanged: (v) => ref.read(userServiceProvider).updateNotificationPrefs(
                    profile.uid,
                    profile.notifPrefs.copyWith(moodReminders: v),
                  ),
            ),
            SwitchListTile(
              title: const Text('Calendar reminders'),
              value: profile.notifPrefs.calendarReminders,
              onChanged: (v) => ref.read(userServiceProvider).updateNotificationPrefs(
                    profile.uid,
                    profile.notifPrefs.copyWith(calendarReminders: v),
                  ),
            ),
            SwitchListTile(
              title: const Text('Emergency alerts'),
              value: profile.notifPrefs.emergencyAlerts,
              onChanged: (v) => ref.read(userServiceProvider).updateNotificationPrefs(
                    profile.uid,
                    profile.notifPrefs.copyWith(emergencyAlerts: v),
                  ),
            ),
            const SizedBox(height: 24),
            const Text('Quiet hours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text('Enable quiet hours'),
              subtitle: const Text('Reminders are suppressed during this window'),
              value: profile.quietHours.enabled,
              onChanged: (v) => ref.read(userServiceProvider).updateQuietHours(
                    profile.uid,
                    profile.quietHours.copyWith(enabled: v),
                  ),
            ),
            if (profile.quietHours.enabled)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _HourPicker(
                        label: 'From',
                        hour: profile.quietHours.startHour,
                        onChanged: (h) => ref.read(userServiceProvider).updateQuietHours(
                              profile.uid,
                              profile.quietHours.copyWith(startHour: h),
                            ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _HourPicker(
                        label: 'Until',
                        hour: profile.quietHours.endHour,
                        onChanged: (h) => ref.read(userServiceProvider).updateQuietHours(
                              profile.uid,
                              profile.quietHours.copyWith(endHour: h),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            if (profile.hasPartner)
              ListTile(
                leading: const Icon(Icons.link_off, color: Colors.red),
                title: const Text('Unlink partner', style: TextStyle(color: Colors.red)),
                subtitle: const Text("Removes shared data for both of you. This can't be undone."),
                onTap: () => _confirmUnlink(context, ref, profile.coupleId!, profile.uid),
              ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () => ref.read(authServiceProvider).signOut(),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _confirmUnlink(
    BuildContext context,
    WidgetRef ref,
    String coupleId,
    String uid,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink partner?'),
        content: const Text(
          'This permanently deletes your shared mood history and alerts, and '
          "disconnects both accounts. Neither of you can undo this.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unlink', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(coupleServiceProvider).deleteCoupleCascade(coupleId);
    await ref.read(userServiceProvider).clearPartnerLink(uid);
  }
}

class _HourPicker extends StatelessWidget {
  const _HourPicker({required this.label, required this.hour, required this.onChanged});

  final String label;
  final int hour;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: hour,
      decoration: InputDecoration(labelText: label),
      items: [
        for (var h = 0; h < 24; h++)
          DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}:00')),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
