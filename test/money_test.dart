import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/models/money.dart';

void main() {
  group('Money currency safety', () {
    test('adds within the same currency', () {
      final a = Money(minorUnits: 1000, currency: 'GHS');
      final b = Money(minorUnits: 250, currency: 'GHS');
      expect((a + b).minorUnits, 1250);
    });

    test('throws when combining different currencies', () {
      final ghs = Money(minorUnits: 1000, currency: 'GHS');
      final ngn = Money(minorUnits: 1000, currency: 'NGN');
      expect(() => ghs + ngn, throwsArgumentError);
      expect(() => ghs - ngn, throwsArgumentError);
    });

    test('multiplies by quantity keeping currency', () {
      final price = Money(minorUnits: 500, currency: 'KES');
      final total = price * 3;
      expect(total.minorUnits, 1500);
      expect(total.currency, 'KES');
    });

    test('fromMap requires a currency', () {
      expect(() => Money.fromMap({'minorUnits': 100}), throwsArgumentError);
      expect(
        () => Money.fromMap({'minorUnits': 100, 'currency': ''}),
        throwsArgumentError,
      );
      final m = Money.fromMap({'minorUnits': 100, 'currency': 'ZAR'});
      expect(m.currency, 'ZAR');
    });
  });
}
