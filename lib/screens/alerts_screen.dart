import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AlertsScreen extends StatefulWidget {
  final User user;
  const AlertsScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late final FirebaseFirestore _db;
  String? _processingRequestId;
  List<QueryDocumentSnapshot> _cachedAlerts = [];

  @override
  void initState() {
    super.initState();
    _db = FirebaseFirestore.instance;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('alerts')
          .where('toUid', isEqualTo: widget.user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            _cachedAlerts.isEmpty;
        final hasError = snapshot.hasError && _cachedAlerts.isEmpty;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          _cachedAlerts = snapshot.data!.docs;
        }

        return CustomScrollView(
          slivers: [
            if (hasError)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Unable to load alerts: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_cachedAlerts.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('No alerts yet')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final itemIndex = index ~/ 2;
                      if (index.isOdd) return const SizedBox(height: 12);

                      final doc = _cachedAlerts[itemIndex];
                      final data = doc.data() as Map<String, dynamic>;
                      final type = data['type'] as String? ?? '';
                      final message = data['message'] as String? ?? 'Alert';
                      final requestId = data['requestId'] as String?;

                      if (type == 'partner_link_request' && requestId != null) {
                        return _buildLinkRequestCard(doc.id, requestId, message);
                      }
                      return _buildAlertCard(message, type: type);
                    },
                    childCount: _cachedAlerts.length * 2 - 1,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAlertCard(String message, {String? type}) {
    return _buildCard(
      child: ListTile(
        leading: const Icon(Icons.notifications_none),
        title: Text(message),
        subtitle: type == null ? null : Text(type),
      ),
    );
  }

  Widget _buildLinkRequestCard(
    String alertId,
    String requestId,
    String message,
  ) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('link_requests').doc(requestId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final status = data?['status'] as String? ?? 'pending';
        final isPending = status == 'pending';
        final busy = _processingRequestId == requestId;

        return _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.link, color: Color(0xFF8B7FD8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Status: ${status[0].toUpperCase()}${status.substring(1)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (isPending)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            busy
                                ? null
                                : () => _handleRequest(
                                  alertId: alertId,
                                  requestId: requestId,
                                  accept: false,
                                ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            busy
                                ? null
                                : () => _handleRequest(
                                  alertId: alertId,
                                  requestId: requestId,
                                  accept: true,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B7FD8),
                        ),
                        child:
                            busy
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text(
                                  'Accept',
                                  style: TextStyle(color: Colors.white),
                                ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Future<void> _handleRequest({
    required String alertId,
    required String requestId,
    required bool accept,
  }) async {
    setState(() => _processingRequestId = requestId);

    try {
      final requestRef = _db.collection('link_requests').doc(requestId);
      final userRef = _db.collection('users').doc(widget.user.uid);
      final userSnap = await userRef.get();
      final currentName =
          (userSnap.data()?['name'] as String?) ??
          (widget.user.displayName ?? 'Partner');
      final currentEmail = widget.user.email ?? '';

      final coupleRef = _db.collection('couples').doc();

      await _db.runTransaction((tx) async {
        final requestSnap = await tx.get(requestRef);
        if (!requestSnap.exists) {
          throw StateError('Request not found');
        }
        final data = requestSnap.data() as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'pending';
        if (status != 'pending') {
          return;
        }

        final fromUid = data['fromUid'] as String?;
        final fromEmail = data['fromEmail'] as String? ?? '';
        final fromName = data['fromName'] as String? ?? 'Partner';
        final toUid = data['toUid'] as String? ?? widget.user.uid;

        if (fromUid == null) {
          throw StateError('Missing requester');
        }

        if (accept) {
          tx.set(coupleRef, {
            'members': [fromUid, toUid],
            'createdAt': FieldValue.serverTimestamp(),
          });

          tx.set(_db.collection('users').doc(fromUid), {
            'partnerUid': toUid,
            'partnerEmail': currentEmail,
            'partnerName': currentName,
            'coupleId': coupleRef.id,
          }, SetOptions(merge: true));

          tx.set(_db.collection('users').doc(toUid), {
            'partnerUid': fromUid,
            'partnerEmail': fromEmail,
            'partnerName': fromName,
            'coupleId': coupleRef.id,
          }, SetOptions(merge: true));

          tx.update(requestRef, {
            'status': 'accepted',
            'coupleId': coupleRef.id,
          });
        } else {
          tx.update(requestRef, {'status': 'rejected'});
        }

        tx.set(_db.collection('alerts').doc(alertId), {
          'read': true,
        }, SetOptions(merge: true));
      });

      final requestSnap = await requestRef.get();
      final data = requestSnap.data();
      final fromUid = data?['fromUid'] as String?;
      if (fromUid != null) {
        await _db.collection('alerts').add({
          'toUid': fromUid,
          'fromUid': widget.user.uid,
          'type': 'partner_link_result',
          'message':
              accept
                  ? 'Partner linked successfully!'
                  : 'Partner rejected link request.',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      _showSnack(accept ? 'Partner linked' : 'Link request rejected');
    } catch (_) {
      _showSnack('Unable to process request');
    } finally {
      if (mounted) setState(() => _processingRequestId = null);
    }
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
}

// Firestore security rules suggestion (do not implement here):
// - Allow read/write on users/{uid} only to authenticated user == uid.
// - Allow create on link_requests for authenticated users; updates only by
//   requester or recipient when status is pending.
// - Allow read on link_requests only to fromUid or toUid.
// - Allow create on alerts to authenticated users; read only to alert.toUid.
// - Allow read/write on couples/{coupleId} only to member UIDs in the document.
