/// Mirrors couples/{coupleId} (SRS §3.3, shared scope — memberUids only).
class Couple {
  const Couple({
    required this.id,
    required this.memberUids,
    required this.status,
    required this.initiatedByUid,
  });

  final String id;
  final List<String> memberUids;

  /// pendingConfirmation | active
  final String status;
  final String initiatedByUid;

  bool get isActive => status == 'active';

  String? otherMember(String myUid) {
    for (final uid in memberUids) {
      if (uid != myUid) return uid;
    }
    return null;
  }

  factory Couple.fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) {
      return Couple(id: id, memberUids: const [], status: 'unknown', initiatedByUid: '');
    }
    return Couple(
      id: id,
      memberUids: (data['memberUids'] as List?)?.cast<String>() ?? const [],
      status: data['status'] as String? ?? 'unknown',
      initiatedByUid: data['initiatedByUid'] as String? ?? '',
    );
  }
}
