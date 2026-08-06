import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/invite.dart';
import 'firestore_paths.dart';

const _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // no 0/O/1/I/L
const _codeLength = 8;
const _inviteValidity = Duration(hours: 48);

class InviteService {
  InviteService(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection(FirestorePaths.invites);

  String _generateCode() {
    final rand = Random.secure();
    return List.generate(
      _codeLength,
      (_) => _codeAlphabet[rand.nextInt(_codeAlphabet.length)],
    ).join();
  }

  /// Creates a single-use invite code for [fromUid]. Retries on the (rare)
  /// chance of a code collision.
  Future<String> createInvite(String fromUid) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _generateCode();
      final doc = _invites.doc(code);
      final existing = await doc.get();
      if (existing.exists) continue;

      await doc.set({
        'fromUid': fromUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(_inviteValidity)),
      });
      return code;
    }
    throw StateError('Could not generate a unique invite code, please try again.');
  }

  Future<Invite?> getInvite(String code) async {
    final snap = await _invites.doc(code).get();
    if (!snap.exists) return null;
    return Invite.fromMap(code, snap.data());
  }

  Future<void> cancelInvite(String code) {
    return _invites.doc(code).update({'status': 'cancelled'});
  }

  /// Redeems [code] for [redeemerUid]: creates the shared couples/{coupleId}
  /// doc (pending mutual confirmation) and marks the invite accepted, as one
  /// atomic batch. Returns the new coupleId.
  Future<String> redeemInvite({required String code, required String redeemerUid}) async {
    final invite = await getInvite(code);
    if (invite == null) throw StateError('Invite code not found.');
    if (invite.fromUid == redeemerUid) throw StateError('You cannot redeem your own invite.');
    if (!invite.isPending) throw StateError('This invite is no longer available.');
    if (invite.isExpired) throw StateError('This invite code has expired.');

    final coupleRef = _db.collection(FirestorePaths.couples).doc();
    final batch = _db.batch();
    batch.set(coupleRef, {
      'memberUids': [invite.fromUid, redeemerUid],
      'status': 'pendingConfirmation',
      'initiatedByUid': invite.fromUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_invites.doc(code), {
      'status': 'accepted',
      'acceptedByUid': redeemerUid,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return coupleRef.id;
  }
}
