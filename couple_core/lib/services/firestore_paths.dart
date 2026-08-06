/// Single source of truth for Firestore collection names (SRS §3.3).
class FirestorePaths {
  static const users = 'users';
  static const invites = 'invites';
  static const couples = 'couples';

  // couples/{coupleId}/** subcollections
  static const moods = 'moods';
  static const alerts = 'alerts';
}
