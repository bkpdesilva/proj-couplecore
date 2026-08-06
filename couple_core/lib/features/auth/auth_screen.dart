import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../services/auth_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CoupleCore - Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            if (!_isRegister)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading ? null : _showForgotPasswordDialog,
                  child: const Text('Forgot password?'),
                ),
              ),
            const SizedBox(height: 8),
            if (_loading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _submitWithEmail,
                child: Text(_isRegister ? 'Register' : 'Sign In'),
              ),
            TextButton(
              onPressed: () => setState(() => _isRegister = !_isRegister),
              child: Text(
                _isRegister ? 'Have an account? Sign in' : 'Create account',
              ),
            ),
            const SizedBox(height: 16),
            const Row(children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('or'),
              ),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loading ? null : _submitWithGoogle,
              icon: const Icon(Icons.login),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loading ? null : _submitWithApple,
              icon: const Icon(Icons.apple),
              label: const Text('Continue with Apple'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncProfile(User user, String provider) {
    return ref.read(userServiceProvider).syncOnSignIn(
          uid: user.uid,
          email: user.email,
          authProvider: provider,
        );
  }

  Future<void> _runAuthAction(Future<UserCredential> Function() action, String provider) async {
    setState(() => _loading = true);
    try {
      final cred = await action();
      final user = cred.user;
      if (user != null) await _syncProfile(user, provider);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message ?? 'Auth error')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitWithEmail() async {
    final authService = ref.read(authServiceProvider);
    final email = _emailController.text.trim();
    final pass = _passwordController.text;
    await _runAuthAction(
      () => _isRegister
          ? authService.registerWithEmail(email: email, password: pass)
          : authService.signInWithEmail(email: email, password: pass),
      AuthProviders.password,
    );
  }

  Future<void> _submitWithGoogle() async {
    await _runAuthAction(
      () => ref.read(authServiceProvider).signInWithGoogle(),
      AuthProviders.google,
    );
  }

  Future<void> _submitWithApple() async {
    await _runAuthAction(
      () => ref.read(authServiceProvider).signInWithApple(),
      AuthProviders.apple,
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final controller = TextEditingController(text: _emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Send reset link'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty || !mounted) return;

    try {
      await ref.read(authServiceProvider).sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to $email')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message ?? 'Could not send reset email')));
      }
    }
  }
}
