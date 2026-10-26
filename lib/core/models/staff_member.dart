import 'package:flutter/foundation.dart';

/// A user holding a staff role (admin or courier), mirrored from their custom
/// claims into `staff/{uid}` by the `setUserRole` Cloud Function.
@immutable
class StaffMember {
  const StaffMember({
    required this.uid,
    required this.role,
    this.adminTier,
    this.displayName,
    this.email,
    this.phone,
  });

  final String uid;

  /// `admin` or `delivery`.
  final String role;
  final String? adminTier;
  final String? displayName;
  final String? email;
  final String? phone;

  /// Best human-readable name available.
  String get label => displayName ?? email ?? phone ?? uid;

  factory StaffMember.fromMap(String uid, Map<String, dynamic> map) =>
      StaffMember(
        uid: uid,
        role: map['role'] as String? ?? '',
        adminTier: map['adminTier'] as String?,
        displayName: map['displayName'] as String?,
        email: map['email'] as String?,
        phone: map['phone'] as String?,
      );
}
