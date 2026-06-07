/// The three actor types in the Shop Afrik marketplace (plan §2).
///
/// A single authenticated account maps to exactly one active role for a
/// session. Admins are provisioned out-of-band; buyers and sellers
/// self-onboard.
enum UserRole {
  buyer,
  seller,
  admin;

  static UserRole fromName(String? name) {
    return UserRole.values.firstWhere(
      (role) => role.name == name,
      orElse: () => UserRole.buyer,
    );
  }
}

/// Admin privilege levels used by the tiered refund-approval flow (§6, §10).
enum AdminTier {
  /// Standard admin — can approve refunds up to tier 1 ceiling.
  admin,

  /// Supervisor — required as a second approver for tier 2 refunds.
  supervisor;

  static AdminTier fromName(String? name) {
    return AdminTier.values.firstWhere(
      (tier) => tier.name == name,
      orElse: () => AdminTier.admin,
    );
  }
}
