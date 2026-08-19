import 'notification_settings.dart';

/// Mirrors users/{uid} (SRS §3.3, account scope — owner-only).
class UserProfile {
  const UserProfile({
    required this.uid,
    this.email,
    this.authProviders = const [],
    this.partnerUid,
    this.coupleId,
    this.notifPrefs = const NotificationPrefs(),
    this.quietHours = const QuietHours(),
  });

  final String uid;
  final String? email;
  final List<String> authProviders;
  final String? partnerUid;
  final String? coupleId;
  final NotificationPrefs notifPrefs;
  final QuietHours quietHours;

  bool get hasPartner => coupleId != null;

  factory UserProfile.fromMap(String uid, Map<String, dynamic>? data) {
    if (data == null) return UserProfile(uid: uid);
    final settings = data['settings'] as Map<String, dynamic>?;
    return UserProfile(
      uid: uid,
      email: data['email'] as String?,
      authProviders: (data['authProviders'] as List?)?.cast<String>() ?? const [],
      partnerUid: data['partnerUid'] as String?,
      coupleId: data['coupleId'] as String?,
      notifPrefs: NotificationPrefs.fromMap(settings?['notifPrefs'] as Map<String, dynamic>?),
      quietHours: QuietHours.fromMap(settings?['quietHours'] as Map<String, dynamic>?),
    );
  }
}
