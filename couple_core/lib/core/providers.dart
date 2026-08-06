import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/couple.dart';
import '../models/user_profile.dart';
import '../services/alert_service.dart';
import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../services/invite_service.dart';
import '../services/mood_service.dart';
import '../services/user_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authServiceProvider =
    Provider<AuthService>((ref) => AuthService(ref.watch(firebaseAuthProvider)));
final userServiceProvider =
    Provider<UserService>((ref) => UserService(ref.watch(firestoreProvider)));
final moodServiceProvider =
    Provider<MoodService>((ref) => MoodService(ref.watch(firestoreProvider)));
final alertServiceProvider =
    Provider<AlertService>((ref) => AlertService(ref.watch(firestoreProvider)));
final inviteServiceProvider =
    Provider<InviteService>((ref) => InviteService(ref.watch(firestoreProvider)));
final coupleServiceProvider =
    Provider<CoupleService>((ref) => CoupleService(ref.watch(firestoreProvider)));

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

/// Live profile for the signed-in user. Only meaningful once authStateProvider
/// has a user — AuthGate guarantees that for every screen that reads this.
final myProfileProvider = StreamProvider<UserProfile>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(userServiceProvider).watchProfile(uid);
});

/// The signed-in user's couple, however far linking has progressed
/// (pendingConfirmation or active), or null if unlinked. Queries by
/// memberUids directly rather than via myProfileProvider.coupleId so it
/// stays correct mid-linking, before the profile mirror catches up.
final myCoupleProvider = StreamProvider<Couple?>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(coupleServiceProvider).watchMyCouple(uid);
});

typedef MoodQuery = ({String coupleId, String uid});

final moodStreamProvider =
    StreamProvider.family<DocumentSnapshot<Map<String, dynamic>>, MoodQuery>((ref, query) {
  return ref.watch(moodServiceProvider).watchMood(query.coupleId, query.uid);
});
