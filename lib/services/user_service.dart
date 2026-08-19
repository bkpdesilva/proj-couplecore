import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification_settings.dart';
import '../models/user_profile.dart';
import 'firestore_paths.dart';

class UserService {
  UserService(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      _db.collection(FirestorePaths.users).doc(uid);

  /// Bootstraps the profile on first sign-up and keeps email + the set of
  /// providers used to sign in up to date on every later sign-in. Merge-based
  /// and idempotent, so one method covers both register and sign-in.
  Future<void> syncOnSignIn({
    required String uid,
    required String? email,
    required String authProvider,
  }) {
    return userDoc(uid).set({
      'email': email,
      'authProviders': FieldValue.arrayUnion([authProvider]),
    }, SetOptions(merge: true));
  }

  Stream<UserProfile> watchProfile(String uid) {
    return userDoc(uid).snapshots().map((snap) => UserProfile.fromMap(uid, snap.data()));
  }

  Future<UserProfile> getProfile(String uid) async {
    final snap = await userDoc(uid).get();
    return UserProfile.fromMap(uid, snap.data());
  }

  /// Self-write only: a user's partnerUid/coupleId are always set by that
  /// same user's own client, driven by the shared couples/{coupleId} doc —
  /// never written by the partner (see firestore.rules, CoupleService).
  Future<void> setPartnerLink({
    required String uid,
    required String partnerUid,
    required String coupleId,
  }) {
    return userDoc(uid).set({
      'partnerUid': partnerUid,
      'coupleId': coupleId,
    }, SetOptions(merge: true));
  }

  Future<void> clearPartnerLink(String uid) {
    return userDoc(uid).set({
      'partnerUid': null,
      'coupleId': null,
    }, SetOptions(merge: true));
  }

  Future<void> updateNotificationPrefs(String uid, NotificationPrefs prefs) {
    return userDoc(uid).set({
      'settings': {'notifPrefs': prefs.toMap()},
    }, SetOptions(merge: true));
  }

  Future<void> updateQuietHours(String uid, QuietHours quietHours) {
    return userDoc(uid).set({
      'settings': {'quietHours': quietHours.toMap()},
    }, SetOptions(merge: true));
  }
}
