import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Login gate. Pops with `true` if the user successfully signs in / signs up,
/// `false` (or null) if they back out. Supports email/password (with sign-up
/// toggle), Google, Apple (iOS/macOS only), and Phone OTP.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.headline = "Sign in to continue"});
  final String headline;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Mode { signIn, signUp }

class _LoginScreenState extends State<LoginScreen> {
  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  String? _error;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool get _isSignUp => _mode == _Mode.signUp;
  bool get _appleAvailable =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<T?> _wrap<T>(Future<T> Function() task) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      return await task();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _humanise(e));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return null;
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailCtrl.text.trim();
    final pw = _passwordCtrl.text;
    final cred = await _wrap(() async {
      if (_isSignUp) {
        if (_confirmCtrl.text != pw) {
          throw FirebaseAuthException(
              code: 'mismatch', message: "Passwords don't match.");
        }
        return AuthService.instance
            .signUpWithEmail(email, pw, displayName: _nameCtrl.text.trim());
      }
      return AuthService.instance.signInWithEmail(email, pw);
    });
    if (cred != null && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _google() async {
    final cred = await _wrap(() => AuthService.instance.signInWithGoogle());
    if (cred != null && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _apple() async {
    final cred = await _wrap(() => AuthService.instance.signInWithApple());
    if (cred != null && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _phone() async {
    final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const _PhoneLoginScreen()));
    if (ok == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = "Enter your email first, then tap Reset.");
      return;
    }
    final sent = await _wrap(() async {
      await AuthService.instance.sendPasswordReset(email);
      return true;
    });
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Reset email sent to $email")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignUp ? 'Create account' : 'Sign in'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.headline,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                _isSignUp
                    ? "Pick any method below. Already have an account? Tap Sign in."
                    : "Pick any method below. New here? Tap Create account.",
                style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: 22),

              // Provider buttons -----------------------------------------------
              _ProviderButton(
                onPressed: _busy ? null : _google,
                label: 'Continue with Google',
                bg: Colors.white,
                fg: Colors.black87,
                icon: _googleG(),
                border: Colors.black12,
              ),
              const SizedBox(height: 10),
              if (_appleAvailable) ...[
                _ProviderButton(
                  onPressed: _busy ? null : _apple,
                  label: 'Continue with Apple',
                  bg: Colors.black,
                  fg: Colors.white,
                  icon: const Icon(Icons.apple, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 10),
              ],
              _ProviderButton(
                onPressed: _busy ? null : _phone,
                label: 'Continue with phone',
                bg: const Color(0xFFEDE6D2),
                fg: Colors.black87,
                icon: const Icon(Icons.phone_outlined,
                    color: Colors.black54, size: 20),
                border: Colors.black12,
              ),

              // Divider --------------------------------------------------------
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: Divider(color: Colors.black.withValues(alpha: 0.15))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text("OR",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          color: Colors.black45)),
                ),
                Expanded(child: Divider(color: Colors.black.withValues(alpha: 0.15))),
              ]),

              // Mode tabs ------------------------------------------------------
              const SizedBox(height: 16),
              SegmentedButton<_Mode>(
                segments: const [
                  ButtonSegment(value: _Mode.signIn, label: Text('Sign in')),
                  ButtonSegment(value: _Mode.signUp, label: Text('Create account')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) =>
                    setState(() => _mode = s.first),
              ),
              const SizedBox(height: 16),

              // Email form -----------------------------------------------------
              Form(
                key: _formKey,
                child: Column(children: [
                  if (_isSignUp) ...[
                    TextFormField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                          labelText: 'Display name (optional)'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? "Enter a valid email" : null,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    textInputAction:
                        _isSignUp ? TextInputAction.next : TextInputAction.done,
                    autofillHints: _isSignUp
                        ? const [AutofillHints.newPassword]
                        : const [AutofillHints.password],
                    validator: (v) => (v == null || v.length < 6)
                        ? "At least 6 characters"
                        : null,
                    decoration: const InputDecoration(labelText: 'Password'),
                    onFieldSubmitted: (_) => _isSignUp ? null : _submitEmail(),
                  ),
                  if (_isSignUp) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      validator: (v) => v != _passwordCtrl.text
                          ? "Passwords don't match"
                          : null,
                      decoration:
                          const InputDecoration(labelText: 'Confirm password'),
                      onFieldSubmitted: (_) => _submitEmail(),
                    ),
                  ],
                ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD32F2F).withValues(alpha: 0.08),
                    border: const Border(
                        left: BorderSide(color: Color(0xFFD32F2F), width: 3)),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(color: Color(0xFFD32F2F))),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submitEmail,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_isSignUp ? 'Create account' : 'Sign in'),
              ),
              if (!_isSignUp) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _resetPassword,
                  child: const Text('Forgot password? Send a reset email'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _humanise(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
        return "Wrong email or password.";
      case 'user-not-found':
        return "No user with that email — switch to Create account.";
      case 'email-already-in-use':
        return "That email is already registered. Switch to Sign in.";
      case 'weak-password':
        return "Password must be at least 6 characters.";
      case 'invalid-email':
        return "That doesn't look like a valid email.";
      case 'too-many-requests':
        return "Too many attempts. Try again in a minute.";
      case 'network-request-failed':
        return "Network error — check your connection.";
      case 'cancelled':
        return e.message ?? "Sign-in was cancelled.";
      case 'mismatch':
        return e.message ?? "Passwords don't match.";
      default:
        return e.message ?? e.code;
    }
  }

  Widget _googleG() => Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: const BoxDecoration(),
        child: const Text(
          'G',
          style: TextStyle(
              color: Color(0xFF4285F4),
              fontWeight: FontWeight.w900,
              fontSize: 18),
        ),
      );
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.onPressed,
    required this.label,
    required this.bg,
    required this.fg,
    required this.icon,
    this.border,
  });
  final VoidCallback? onPressed;
  final String label;
  final Color bg;
  final Color fg;
  final Widget icon;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          side: border == null ? null : BorderSide(color: border!),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14.5)),
          ],
        ),
      ),
    );
  }
}

/// Two-step phone sign-in. Pops `true` on success.
class _PhoneLoginScreen extends StatefulWidget {
  const _PhoneLoginScreen();
  @override
  State<_PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<_PhoneLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String? _verificationId;
  bool _busy = false;
  String? _error;

  Future<void> _sendCode() async {
    final num = _phoneCtrl.text.trim();
    if (!RegExp(r'^\+\d{8,15}$').hasMatch(num)) {
      setState(() => _error =
          "Use E.164 format with country code, e.g. +919876543210");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await AuthService.instance.startPhoneSignIn(
      num,
      onCodeSent: (id) {
        setState(() {
          _verificationId = id;
          _busy = false;
        });
      },
      onError: (e) {
        setState(() {
          _error = e.message ?? e.code;
          _busy = false;
        });
      },
      onAutoVerified: (credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) Navigator.of(context).pop(true);
        } catch (_) {}
      },
    );
  }

  Future<void> _verify() async {
    if (_verificationId == null) return;
    final code = _codeCtrl.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = "Enter the 6-digit code.");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.verifySms(_verificationId!, code);
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onCodeStep = _verificationId != null;
    return Scaffold(
      appBar: AppBar(title: Text(onCodeStep ? 'Enter code' : 'Phone sign-in')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!onCodeStep) ...[
            const Text("We'll text you a 6-digit code via Firebase Auth.",
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Phone (E.164)',
                  hintText: '+91 98765 43210'),
            ),
          ] else ...[
            Text("Code sent to ${_phoneCtrl.text}.",
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: '6-digit code'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Color(0xFFD32F2F))),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : (onCodeStep ? _verify : _sendCode),
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(onCodeStep ? 'Verify & sign in' : 'Send code'),
          ),
          if (onCodeStep)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _verificationId = null;
                        _codeCtrl.clear();
                      }),
              child: const Text('← Use a different number'),
            ),
        ]),
      ),
    );
  }
}

/// Convenience: push the login screen. Returns `true` on success.
Future<bool> showLoginGate(BuildContext context,
    {String headline = "Sign in to continue"}) async {
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LoginScreen(headline: headline)));
  return ok == true;
}
