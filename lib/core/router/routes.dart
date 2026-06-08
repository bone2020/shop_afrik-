/// Centralized route path constants for Shop Afrik.
abstract final class Routes {
  // Entry / auth
  static const String splash = '/';
  static const String signIn = '/sign-in';

  // Buyer
  static const String buyerHome = '/buyer';
  static const String buyerCheckout = '/buyer/checkout';
  static const String buyerProductPath = '/buyer/product/:id';
  static String buyerProduct(String id) => '/buyer/product/$id';
  static const String buyerOrderPath = '/buyer/orders/:id';
  static String buyerOrder(String id) => '/buyer/orders/$id';
  static const String buyerBecomeSeller = '/buyer/become-seller';

  // Seller
  static const String sellerDashboard = '/seller';
  static const String sellerProductNew = '/seller/product/new';
  static const String sellerProductEditPath = '/seller/product/:id/edit';
  static String sellerProductEdit(String id) => '/seller/product/$id/edit';

  // Admin
  static const String adminDashboard = '/admin';
}
