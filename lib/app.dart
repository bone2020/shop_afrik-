import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/session_controller.dart';

/// Root application widget. Watches app lifecycle to force an ID-token refresh
/// on resume, so a role granted while the app was backgrounded (e.g. seller
/// approval) is picked up.
class ShopAfrikApp extends ConsumerStatefulWidget {
  const ShopAfrikApp({super.key});

  @override
  ConsumerState<ShopAfrikApp> createState() => _ShopAfrikAppState();
}

class _ShopAfrikAppState extends ConsumerState<ShopAfrikApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(sessionControllerProvider.notifier).refreshClaims();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
