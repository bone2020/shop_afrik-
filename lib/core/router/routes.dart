/// Centralized route path constants for Shop Afrik.
abstract final class Routes {
  // Entry / auth
  static const String splash = '/';
  static const String signIn = '/sign-in';

  // Buyer
  static const String buyerHome = '/buyer';
  static const String buyerCart = '/buyer/cart';
  static const String buyerOrders = '/buyer/orders';

  // Seller
  static const String sellerDashboard = '/seller';
  static const String sellerProducts = '/seller/products';
  static const String sellerOrders = '/seller/orders';

  // Admin
  static const String adminDashboard = '/admin';
  static const String adminApprovals = '/admin/approvals';
  static const String adminRefunds = '/admin/refunds';
}
