import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/auth_service.dart';

/// Asks an email/password user to verify their address before checking out
/// or selling (SA-102). The server enforces the same rule; this explains it
/// and lets the user resend the link or confirm they have clicked it.
class EmailVerificationBanner extends ConsumerStatefulWidget {
  const EmailVerificationBanner({
    super.key,
    required this.action,
    required this.onVerified,
  });

  /// What verification unlocks, e.g. "check out".
  final String action;
  final VoidCallback onVerified;

  @override
  ConsumerState<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState
    extends ConsumerState<EmailVerificationBanner> {
  bool _busy = false;
  String? _note;

  @override
  Widget build(BuildContext context) {
    final email = ref.read(authServiceProvider).currentUser?.email ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.mark_email_unread_outlined,
                    color: AppColors.brightAqua),
                SizedBox(width: 8),
                Text('Verify your email',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'We sent a link to $email. Tap it, then come back to '
              '${widget.action}.',
              style: const TextStyle(color: AppColors.mutedText),
            ),
            if (_note != null) ...[
              const SizedBox(height: 8),
              Text(_note!),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : _check,
                  child: const Text("I've verified"),
                ),
                TextButton(
                  onPressed: _busy ? null : _resend,
                  child: const Text('Resend link'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _check() async {
    setState(() => _busy = true);
    try {
      final ok = await ref.read(authServiceProvider).refreshEmailVerified();
      if (ok) {
        widget.onVerified();
      } else if (mounted) {
        setState(() => _note = 'Not verified yet. Check your inbox and spam.');
      }
    } catch (e) {
      if (mounted) setState(() => _note = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).sendEmailVerification();
      if (mounted) setState(() => _note = 'Link sent again.');
    } catch (e) {
      if (mounted) setState(() => _note = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
