import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors invites/{code} (SRS §3.3).
class Invite {
  const Invite({
    required this.code,
    required this.fromUid,
    required this.status,
    this.expiresAt,
  });

  final String code;
  final String fromUid;

  /// pending | accepted | expired | cancelled
  final String status;
  final DateTime? expiresAt;

  bool get isPending => status == 'pending';
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  factory Invite.fromMap(String code, Map<String, dynamic>? data) {
    if (data == null) {
      return Invite(code: code, fromUid: '', status: 'unknown');
    }
    final expiresAtRaw = data['expiresAt'];
    return Invite(
      code: code,
      fromUid: data['fromUid'] as String? ?? '',
      status: data['status'] as String? ?? 'unknown',
      expiresAt: expiresAtRaw is Timestamp ? expiresAtRaw.toDate() : null,
    );
  }
}
