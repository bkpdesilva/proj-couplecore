import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/couple.dart';

/// FR-8/9/11: generate/redeem an invite code, then mutual confirmation.
/// The actual users/{uid}.partnerUid / coupleId self-write, once the couple
/// goes active, happens in DashboardScreen (it owns the auth-scoped
/// lifecycle) — this screen only drives the couples/{coupleId} state.
class LinkPartnerScreen extends ConsumerStatefulWidget {
  const LinkPartnerScreen({super.key});

  @override
  ConsumerState<LinkPartnerScreen> createState() => _LinkPartnerScreenState();
}

class _LinkPartnerScreenState extends ConsumerState<LinkPartnerScreen> {
  final _codeController = TextEditingController();
  String? _generatedCode;
  bool _generating = false;
  bool _redeeming = false;
  bool _confirming = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String get _myUid => ref.read(authStateProvider).value!.uid;

  Future<void> _generateCode() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final code = await ref.read(inviteServiceProvider).createInvite(_myUid);
      if (mounted) setState(() => _generatedCode = code);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _redeemCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _redeeming = true;
      _error = null;
    });
    try {
      await ref.read(inviteServiceProvider).redeemInvite(code: code, redeemerUid: _myUid);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  Future<void> _confirm(String coupleId) async {
    setState(() => _confirming = true);
    try {
      await ref.read(coupleServiceProvider).confirmCouple(coupleId);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupleAsync = ref.watch(myCoupleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Link Partner')),
      body: coupleAsync.when(
        data: (couple) {
          if (couple == null) return _buildLinkForm();
          if (couple.status == 'active') return _buildLinked();
          return _buildPendingConfirmation(couple);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildLinkForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Share a code with your partner',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_generatedCode == null)
            ElevatedButton(
              onPressed: _generating ? null : _generateCode,
              child: _generating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Generate invite code'),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    _generatedCode!,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Valid for 48 hours. Share it with your partner however you like.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Have a code from your partner?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Enter invite code',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _redeeming ? null : _redeemCode,
            child: _redeeming
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Link partner'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingConfirmation(Couple couple) {
    final iInitiated = couple.initiatedByUid == _myUid;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_top, size: 48, color: AppTheme.primary),
            const SizedBox(height: 16),
            Text(
              iInitiated
                  ? 'Your partner used your invite code!'
                  : "Almost there — waiting on your partner to confirm.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            if (iInitiated)
              ElevatedButton(
                onPressed: _confirming ? null : () => _confirm(couple.id),
                child: _confirming
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirm link'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLinked() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, size: 48, color: AppTheme.primary),
            const SizedBox(height: 16),
            const Text(
              "You're linked!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
