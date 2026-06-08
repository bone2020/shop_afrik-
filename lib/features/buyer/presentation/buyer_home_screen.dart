import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../services/session_controller.dart';
import '../../notifications/presentation/notifications_bell.dart';
import '../application/cart_controller.dart';
import 'buyer_orders_tab.dart';
import 'cart_tab.dart';
import 'shop_tab.dart';

/// Buyer shell: Shop / Cart / Orders tabs.
class BuyerHomeScreen extends ConsumerStatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  ConsumerState<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends ConsumerState<BuyerHomeScreen> {
  int _index = 0;

  static const _titles = ['Shop Afrik', 'Cart', 'My orders'];

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(cartCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          const NotificationsBell(),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'become_seller') {
                context.push(Routes.buyerBecomeSeller);
              } else if (value == 'addresses') {
                context.push(Routes.buyerAddresses);
              } else if (value == 'sign_out') {
                ref.read(sessionControllerProvider.notifier).signOut();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'addresses', child: Text('Saved addresses')),
              PopupMenuItem(
                  value: 'become_seller', child: Text('Become a seller')),
              PopupMenuItem(value: 'sign_out', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [ShopTab(), CartTab(), BuyerOrdersTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Shop'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            selectedIcon: const Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Orders'),
        ],
      ),
    );
  }
}
