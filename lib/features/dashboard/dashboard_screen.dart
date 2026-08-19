import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/couple.dart';
import '../emergency/emergency_dialog.dart';
import '../linking/link_partner_screen.dart';
import '../mood/mood_picker_sheet.dart';
import '../settings/settings_screen.dart';
import 'widgets/dashboard_bottom_nav.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/feature_grid.dart';
import 'widgets/mood_section.dart';
import 'widgets/partner_link_banner.dart';
import 'widgets/wisdom_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, required this.user});

  final User user;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final myUid = widget.user.uid;

    // Each partner's own client mirrors the shared couple doc into its own
    // users/{uid} — never the other partner's doc (see firestore.rules,
    // CoupleService/UserService docs).
    ref.listen<AsyncValue<Couple?>>(myCoupleProvider, (previous, next) {
      final couple = next.valueOrNull;
      final profile = ref.read(myProfileProvider).valueOrNull;
      final userService = ref.read(userServiceProvider);

      if (couple != null && couple.isActive) {
        final partnerUid = couple.otherMember(myUid);
        if (partnerUid != null &&
            (profile?.coupleId != couple.id || profile?.partnerUid != partnerUid)) {
          userService.setPartnerLink(uid: myUid, partnerUid: partnerUid, coupleId: couple.id);
        }
      } else if (couple == null && profile?.coupleId != null) {
        userService.clearPartnerLink(myUid);
      }
    });

    final couple = ref.watch(myCoupleProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            const DashboardHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      const WisdomCard(),
                      const SizedBox(height: 20),
                      if (couple != null && couple.isActive)
                        _LinkedMoodSection(myUid: myUid, couple: couple)
                      else
                        PartnerLinkBanner(
                          pending: couple != null,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LinkPartnerScreen()),
                          ),
                        ),
                      const SizedBox(height: 24),
                      const FeatureGrid(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEmergencyDialog(couple),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.favorite, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: DashboardBottomNav(
        selectedIndex: _selectedIndex,
        onSelect: _handleNavSelect,
      ),
    );
  }

  Future<void> _handleNavSelect(int index) async {
    if (index == 3) {
      setState(() => _selectedIndex = index);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
      if (mounted) setState(() => _selectedIndex = 0);
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  void _showEmergencyDialog(Couple? couple) {
    showDialog(
      context: context,
      builder: (context) => EmergencyDialog(onConfirm: () => _sendEmergencyNotification(couple)),
    );
  }

  Future<void> _sendEmergencyNotification(Couple? couple) async {
    final myUid = widget.user.uid;
    final partnerUid = couple?.otherMember(myUid);
    if (couple == null || !couple.isActive || partnerUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No partner linked to send emergency')),
        );
        Navigator.pop(context);
      }
      return;
    }
    await ref.read(alertServiceProvider).sendEmergencyAlert(
          coupleId: couple.id,
          fromUid: myUid,
          toUid: partnerUid,
          message: 'Emergency alert from your partner',
        );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency notification sent to partner'),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }
}

/// Live mood tiles for an actively-linked couple. Split out so its two mood
/// stream subscriptions only exist once linking is actually active.
class _LinkedMoodSection extends ConsumerWidget {
  const _LinkedMoodSection({required this.myUid, required this.couple});

  final String myUid;
  final Couple couple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnerUid = couple.otherMember(myUid)!;
    final myMoodSnap =
        ref.watch(moodStreamProvider((coupleId: couple.id, uid: myUid))).valueOrNull;
    final partnerMoodSnap =
        ref.watch(moodStreamProvider((coupleId: couple.id, uid: partnerUid))).valueOrNull;

    final myMood = (myMoodSnap?.data()?['mood'] as String?) ?? '—';
    final partnerMood = (partnerMoodSnap?.data()?['mood'] as String?) ?? '—';

    return MoodSection(
      myMood: myMood,
      partnerMood: partnerMood,
      onTapMyMood: () => _showMoodPicker(context, ref),
    );
  }

  void _showMoodPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => MoodPickerSheet(
        onMoodSelected: (mood) async {
          await ref
              .read(moodServiceProvider)
              .setMood(coupleId: couple.id, uid: myUid, mood: mood);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}
