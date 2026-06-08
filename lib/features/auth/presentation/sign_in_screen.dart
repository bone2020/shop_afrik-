import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/user_role.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/session_controller.dart';

/// Phase 1 entry screen.
///
/// Real authentication (Firebase Auth + phone/email) arrives in Phase 2.
/// For now this lets us sign in as each role to exercise the routing shell
/// and the per-role screens.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(sessionControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(height: 24),
                  Text(
                    AppConfig.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'African marketplace, powered by QR Wallet',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Continue as',
                    style: TextStyle(color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 12),
                  _RoleButton(
                    label: 'Buyer',
                    icon: Icons.shopping_bag_outlined,
                    onTap: () => controller.signInAs(UserRole.buyer),
                  ),
                  const SizedBox(height: 12),
                  _RoleButton(
                    label: 'Seller',
                    icon: Icons.store_outlined,
                    onTap: () => controller.signInAs(UserRole.seller),
                  ),
                  const SizedBox(height: 12),
                  _RoleButton(
                    label: 'Admin',
                    icon: Icons.admin_panel_settings_outlined,
                    onTap: () => controller.signInAs(UserRole.admin),
                  ),
                  const SizedBox(height: 12),
                  _RoleButton(
                    label: 'Delivery',
                    icon: Icons.local_shipping_outlined,
                    onTap: () => controller.signInAs(UserRole.delivery),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
