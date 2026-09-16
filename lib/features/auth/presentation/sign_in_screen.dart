import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../buyer/data/buyer_repository.dart';
import '../data/auth_service.dart';

/// Real authentication entry screen: email/password and phone/OTP. Every role
/// signs in here; the router then sends them to the right surface based on their
/// role claim (buyer by default).
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 72,
                      width: 72,
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront,
                          color: AppColors.primaryDark, size: 36),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppConfig.appName,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'African marketplace, powered by QR Wallet',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.mutedText),
                    ),
                    const SizedBox(height: 24),
                    const TabBar(
                      tabs: [Tab(text: 'Email'), Tab(text: 'Phone')],
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(
                      height: 360,
                      child: TabBarView(
                        children: [_EmailForm(), _PhoneForm()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared helper: create the buyer profile doc for a brand-new account.
Future<void> _ensureBuyerProfile(
  WidgetRef ref,
  User user, {
  required bool isNew,
  String? name,
}) async {
  if (!isNew) return;
  await ref.read(buyerRepositoryProvider).createProfileIfAbsent(
        user.uid,
        name: name ?? user.displayName ?? 'Buyer',
        email: user.email,
        phone: user.phoneNumber,
      );
}

// ---------------------------------------------------------------------------
// Email / password
// ---------------------------------------------------------------------------

class _EmailForm extends ConsumerStatefulWidget {
  const _EmailForm();

  @override
  ConsumerState<_EmailForm> createState() => _EmailFormState();
}

class _EmailFormState extends ConsumerState<_EmailForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_signUp)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  validator: (v) => _signUp && (v == null || v.trim().isEmpty)
                      ? 'Required'
                      : null,
                ),
              ),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'At least 6 characters' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: AppColors.dangerCoral)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_signUp ? 'Create account' : 'Sign in'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _signUp = !_signUp;
                        _error = null;
                      }),
              child: Text(_signUp
                  ? 'Have an account? Sign in'
                  : 'New here? Create an account'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authServiceProvider);
    try {
      if (_signUp) {
        final cred = await auth.registerWithEmail(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
        if (cred.user != null) {
          await _ensureBuyerProfile(ref, cred.user!,
              isNew: true, name: _name.text.trim());
        }
      } else {
        await auth.signInWithEmail(
            email: _email.text, password: _password.text);
      }
      // On success the session updates and the router redirects automatically.
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Phone / OTP
// ---------------------------------------------------------------------------

class _PhoneForm extends ConsumerStatefulWidget {
  const _PhoneForm();

  @override
  ConsumerState<_PhoneForm> createState() => _PhoneFormState();
}

class _PhoneFormState extends ConsumerState<_PhoneForm> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _verificationId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final codeSent = _verificationId != null;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _phone,
            enabled: !codeSent,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+233…',
            ),
          ),
          if (codeSent) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Verification code'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.dangerCoral)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy ? null : (codeSent ? _verify : _sendCode),
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(codeSent ? 'Verify & continue' : 'Send code'),
          ),
          if (codeSent)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _verificationId = null;
                        _code.clear();
                        _error = null;
                      }),
              child: const Text('Use a different number'),
            ),
        ],
      ),
    );
  }

  Future<void> _sendCode() async {
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = 'Enter your phone number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).verifyPhoneNumber(
            phoneNumber: _phone.text,
            verificationCompleted: (credential) async {
              // Android auto-retrieval: sign in straight away.
              final cred = await ref
                  .read(authServiceProvider)
                  .signInWithPhoneCredential(credential);
              await _postPhoneAuth(cred);
            },
            verificationFailed: (e) {
              if (mounted) {
                setState(() {
                  _error = authErrorMessage(e);
                  _busy = false;
                });
              }
            },
            codeSent: (verificationId) {
              if (mounted) {
                setState(() {
                  _verificationId = verificationId;
                  _busy = false;
                });
              }
            },
          );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = authErrorMessage(e);
          _busy = false;
        });
      }
    }
  }

  Future<void> _verify() async {
    if (_code.text.trim().isEmpty) {
      setState(() => _error = 'Enter the code we sent you.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cred = await ref.read(authServiceProvider).signInWithSmsCode(
            verificationId: _verificationId!,
            smsCode: _code.text,
          );
      await _postPhoneAuth(cred);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = authErrorMessage(e);
          _busy = false;
        });
      }
    }
  }

  /// After a successful phone sign-in, create the buyer profile for new users
  /// (prompting for a display name first). The router redirects on session
  /// update.
  Future<void> _postPhoneAuth(UserCredential cred) async {
    final user = cred.user;
    if (user == null) return;
    final isNew = cred.additionalUserInfo?.isNewUser ?? false;
    if (isNew) {
      final name = await _promptName();
      if (name != null && name.isNotEmpty) {
        await ref.read(authServiceProvider).setDisplayName(name);
      }
      await _ensureBuyerProfile(ref, user, isNew: true, name: name);
    }
  }

  Future<String?> _promptName() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Welcome! What should we call you?'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return name;
  }
}
