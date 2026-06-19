import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'alerts_screen.dart';
import 'problem_solver_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final User user;
  const DashboardScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  String partnerMood = '—';
  String myMood = '—';
  String? partnerUid;
  late final FirebaseFirestore _db;
  StreamSubscription? _myMoodSub;
  StreamSubscription? _userDocSub;
  StreamSubscription? _partnerMoodSub;
  String userName = 'User';
  String partnerName = 'Partner';

  @override
  void initState() {
    super.initState();
    _db = FirebaseFirestore.instance;
    _listenToProfileAndMoods();
  }

  void _listenToProfileAndMoods() {
    final user = widget.user;
    final uid = user.uid;
    final userDoc = _db.collection('users').doc(uid);

    userDoc.set({'email': user.email}, SetOptions(merge: true));

    _myMoodSub = _db.collection('moods').doc(uid).snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;
      if (!mounted) return;
      setState(() => myMood = (data['mood'] as String?) ?? myMood);
    });

    _userDocSub = userDoc.snapshots().listen((snap) async {
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;

      if (mounted) {
        setState(() {
          userName =
              data['name'] as String? ?? widget.user.displayName ?? 'User';
          partnerName = data['partnerName'] as String? ?? 'Partner';
        });
      }

      final pUid = data['partnerUid'] as String?;
      final pEmail = data['partnerEmail'] as String?;

      if (pUid != null && pUid != partnerUid) {
        partnerUid = pUid;
        _subscribeToPartnerMood();
      } else if (pUid == null && pEmail != null) {
        final q =
            await _db
                .collection('users')
                .where('email', isEqualTo: pEmail)
                .limit(1)
                .get();
        if (q.docs.isNotEmpty) {
          final found = q.docs.first.id;
          await userDoc.set({'partnerUid': found}, SetOptions(merge: true));
          partnerUid = found;
          _subscribeToPartnerMood();
        }
      }
    });
  }

  void _subscribeToPartnerMood() {
    _partnerMoodSub?.cancel();
    final p = partnerUid;
    if (p == null) return;

    _partnerMoodSub = _db.collection('moods').doc(p).snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;
      if (!mounted) return;
      setState(() => partnerMood = (data['mood'] as String?) ?? partnerMood);
    });
  }

  @override
  void dispose() {
    _myMoodSub?.cancel();
    _userDocSub?.cancel();
    _partnerMoodSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8B7FD8),
      body: SafeArea(child: _buildBody()),
      floatingActionButton:
          _selectedIndex == 0
              ? FloatingActionButton(
                onPressed: _showEmergencyDialog,
                backgroundColor: const Color(0xFF8B7FD8),
                child: const Icon(Icons.favorite, color: Colors.white),
              )
              : null,
      floatingActionButtonLocation:
          _selectedIndex == 0
              ? FloatingActionButtonLocation.centerDocked
              : null,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    final now = DateTime.now();
    final dayName = DateFormat('EEEE').format(now);
    final monthDay = DateFormat('MMMM d').format(now);

    String title;
    Widget pageBody;

    switch (_selectedIndex) {
      case 0:
        title = dayName;
        pageBody = _buildHomeBody();
        break;
      case 1:
        title = 'Timeline';
        pageBody = _buildTimelineBody();
        break;
      case 2:
        title = 'Alerts';
        pageBody = AlertsScreen(user: widget.user);
        break;
      case 3:
        title = 'Settings';
        pageBody = SettingsScreen(user: widget.user);
        break;
      default:
        title = dayName;
        pageBody = _buildHomeBody();
    }

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF8B7FD8),
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          floating: true,
          snap: true,
          elevation: 0,
          expandedHeight: 130,
          toolbarHeight: 0,
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.none,
            background: _buildHeaderContent(title, monthDay),
          ),
        ),
      ],
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF3E8FF),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: pageBody,
      ),
    );
  }

  Widget _buildHeaderContent(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Hello, $userName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                child: const Icon(Icons.person, color: Color(0xFF8B7FD8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHomeBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildMoodSection(),
          const SizedBox(height: 24),
          _buildFeatureGrid(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTimelineBody() {
    return const SingleChildScrollView(
      child: SizedBox(
        height: 500,
        child: Center(
          child: Text(
            'Timeline (coming soon)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }


  Widget _buildMoodSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildPartnerMood(
                  name: userName,
                  mood: myMood,
                  icon: Icons.sentiment_satisfied_alt,
                  onTap: () => _showMoodPicker(true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPartnerMood(
                  name: partnerName,
                  mood: partnerMood,
                  icon: Icons.sentiment_satisfied_alt,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerMood({
    required String name,
    required String mood,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(),
        child: Column(
          children: [
            Icon(icon, size: 40, color: const Color(0xFF8B7FD8)),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C2C2C),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B7FD8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                mood.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureGrid() {
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
          _buildFeatureCard(
            'Shared Calendar',
            Icons.calendar_today,
            const Color(0xFFFFEBEE),
            const Color(0xFFE91E63),
          ),
          _buildFeatureCard(
            'Memories',
            Icons.photo_album,
            const Color(0xFFFFF3E0),
            const Color(0xFFFF9800),
          ),
          _buildFeatureCard(
            'Messages',
            Icons.chat_bubble,
            const Color(0xFFE8F5E9),
            const Color(0xFF4CAF50),
          ),
          _buildFeatureCard(
            'Good Deeds',
            Icons.star,
            const Color(0xFFF3E5F5),
            const Color(0xFF9C27B0),
          ),
          _buildFeatureCard(
            'Problem Solver',
            Icons.psychology_alt,
            const Color(0xFFEDE7F6),
            const Color(0xFF8B7FD8),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProblemSolverScreen(user: widget.user),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    String title,
    IconData icon,
    Color bgColor,
    Color iconColor, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? () => _showSnack('Coming soon: $title'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', 0),
              _buildNavItem(Icons.timeline, 'Timeline', 1),
              const SizedBox(width: 60),
              _buildNavItem(Icons.notifications, 'Alerts', 2),
              _buildNavItem(Icons.settings, 'Settings', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF8B7FD8) : Colors.grey[400],
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? const Color(0xFF8B7FD8) : Colors.grey[400],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoodPicker(bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
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
                    _moodOption('😊', 'Happy', isMe),
                    _moodOption('😐', 'Neutral', isMe),
                    _moodOption('😔', 'Sad', isMe),
                    _moodOption('😰', 'Stressed', isMe),
                    _moodOption('😍', 'Loved', isMe),
                    _moodOption('😤', 'Frustrated', isMe),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
    );
  }

  Widget _moodOption(String emoji, String label, bool isMe) {
    return GestureDetector(
      onTap: () => _handleMoodSelection(label.toLowerCase(), isMe),
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

  Future<void> _handleMoodSelection(String mood, bool isMe) async {
    final uid = widget.user.uid;
    if (isMe) {
      setState(() => myMood = mood);
      await _db.collection('moods').doc(uid).set({
        'mood': mood,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      if (partnerUid != null) {
        await _db.collection('moods').doc(partnerUid).set({
          'mood': mood,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      setState(() => partnerMood = mood);
    }
    if (mounted) Navigator.pop(context);
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Emergency Alert'),
            content: const Text(
              'Send an emergency notification to your partner?',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _sendEmergencyNotification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B7FD8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Send',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _sendEmergencyNotification() async {
    final uid = widget.user.uid;
    final doc = _db.collection('users').doc(uid);
    final snap = await doc.get();
    String? pUid = snap.data()?['partnerUid'] as String?;
    if (pUid == null) {
      if (mounted) {
        _showSnack('No partner linked to send emergency');
        Navigator.pop(context);
      }
      return;
    }
    await _db.collection('alerts').add({
      'fromUid': uid,
      'toUid': pUid,
      'type': 'emergency',
      'message': 'Emergency alert from your partner!',
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Emergency notification sent to partner'),
          backgroundColor: const Color(0xFF8B7FD8),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}
