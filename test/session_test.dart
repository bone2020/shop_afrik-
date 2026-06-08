import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/models/user_role.dart';
import 'package:shop_afrik/services/session_controller.dart';

void main() {
  group('sessionFromClaims (claim → role hydration)', () {
    test('no role claim defaults to buyer', () {
      final s = sessionFromClaims(uid: 'u1', claims: const {});
      expect(s.uid, 'u1');
      expect(s.role, UserRole.buyer);
      expect(s.adminTier, isNull);
      expect(s.isAuthenticated, isTrue);
    });

    test('seller claim maps to seller, no admin tier', () {
      final s = sessionFromClaims(uid: 'u2', claims: const {'role': 'seller'});
      expect(s.role, UserRole.seller);
      expect(s.adminTier, isNull);
    });

    test('delivery claim maps to delivery', () {
      final s =
          sessionFromClaims(uid: 'u3', claims: const {'role': 'delivery'});
      expect(s.role, UserRole.delivery);
    });

    test('admin claim reads adminTier (supervisor)', () {
      final s = sessionFromClaims(
        uid: 'u4',
        claims: const {'role': 'admin', 'adminTier': 'supervisor'},
      );
      expect(s.role, UserRole.admin);
      expect(s.adminTier, AdminTier.supervisor);
    });

    test('admin without adminTier claim defaults to admin tier', () {
      final s = sessionFromClaims(uid: 'u5', claims: const {'role': 'admin'});
      expect(s.role, UserRole.admin);
      expect(s.adminTier, AdminTier.admin);
    });

    test('display name is carried through', () {
      final s = sessionFromClaims(
          uid: 'u6', claims: const {}, displayName: 'Ada');
      expect(s.displayName, 'Ada');
    });

    test('unknown role string falls back to buyer (safe default)', () {
      final s =
          sessionFromClaims(uid: 'u7', claims: const {'role': 'wizard'});
      expect(s.role, UserRole.buyer);
    });
  });
}
