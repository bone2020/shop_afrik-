import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_home_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/buyer/presentation/address_book_screen.dart';
import '../../features/buyer/presentation/buyer_home_screen.dart';
import '../../features/buyer/presentation/buyer_order_detail_screen.dart';
import '../../features/buyer/presentation/checkout_screen.dart';
import '../../features/buyer/presentation/product_detail_screen.dart';
import '../../features/buyer/presentation/seller_storefront_screen.dart';
import '../../features/delivery/presentation/delivery_home_screen.dart';
import '../../features/seller/presentation/product_edit_screen.dart';
import '../../features/seller/presentation/seller_dashboard_screen.dart';
import '../../features/seller/presentation/seller_onboarding_screen.dart';
import '../../services/session_controller.dart';
import '../models/user_role.dart';
import 'routes.dart';

/// Bridges the Riverpod session into a [Listenable] so the router re-evaluates
/// its redirect on sign-in, sign-out, and role-claim changes — without
/// rebuilding the whole [GoRouter] (which would drop navigation state).
class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    ref.listen(sessionControllerProvider, (_, __) => notifyListeners());
  }
}

/// The app router. Redirects are driven by the current [Session] so each role
/// lands in its own section and cannot reach another role's routes.
final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.signIn,
    refreshListenable: refresh,
    redirect: (context, state) {
      // Read (not watch) the latest session at redirect time; refreshes are
      // driven by refreshListenable above.
      final session = ref.read(sessionControllerProvider);
      final loggingIn = state.matchedLocation == Routes.signIn;

      if (!session.isAuthenticated) {
        return loggingIn ? null : Routes.signIn;
      }

      final home = _homeFor(session.role!);

      // Authenticated users on the sign-in screen go to their home.
      if (loggingIn) return home;

      // Keep each role inside its own subtree.
      if (!state.matchedLocation.startsWith(_prefixFor(session.role!))) {
        return home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      // Buyer
      GoRoute(
        path: Routes.buyerHome,
        builder: (context, state) => const BuyerHomeScreen(),
      ),
      GoRoute(
        path: Routes.buyerCheckout,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: Routes.buyerProductPath,
        builder: (context, state) =>
            ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.buyerOrderPath,
        builder: (context, state) =>
            BuyerOrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.buyerBecomeSeller,
        builder: (context, state) => const SellerOnboardingScreen(),
      ),
      GoRoute(
        path: Routes.buyerAddresses,
        builder: (context, state) => const AddressBookScreen(),
      ),
      GoRoute(
        path: Routes.buyerStorePath,
        builder: (context, state) =>
            SellerStorefrontScreen(sellerId: state.pathParameters['id']!),
      ),
      // Seller
      GoRoute(
        path: Routes.sellerDashboard,
        builder: (context, state) => const SellerDashboardScreen(),
      ),
      GoRoute(
        path: Routes.sellerProductNew,
        builder: (context, state) => const ProductEditScreen(),
      ),
      GoRoute(
        path: Routes.sellerProductEditPath,
        builder: (context, state) =>
            ProductEditScreen(productId: state.pathParameters['id']),
      ),
      // Admin
      GoRoute(
        path: Routes.adminDashboard,
        builder: (context, state) => const AdminHomeScreen(),
      ),
      // Delivery
      GoRoute(
        path: Routes.deliveryHome,
        builder: (context, state) => const DeliveryHomeScreen(),
      ),
    ],
  );
});

String _homeFor(UserRole role) => switch (role) {
      UserRole.buyer => Routes.buyerHome,
      UserRole.seller => Routes.sellerDashboard,
      UserRole.admin => Routes.adminDashboard,
      UserRole.delivery => Routes.deliveryHome,
    };

String _prefixFor(UserRole role) => switch (role) {
      UserRole.buyer => '/buyer',
      UserRole.seller => '/seller',
      UserRole.admin => '/admin',
      UserRole.delivery => '/delivery',
    };
