import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/models/currency.dart';
import 'package:shop_afrik/core/models/money.dart';

void main() {
  group('Currency exponents (ISO 4217 — never assume 2 decimals)', () {
    test('default is 2 decimals', () {
      expect(CurrencyMeta.decimalsFor('NGN'), 2);
      expect(CurrencyMeta.decimalsFor('GHS'), 2);
      expect(CurrencyMeta.decimalsFor('MAD'), 2);
      expect(CurrencyMeta.minorUnitsPer('NGN'), 100);
    });

    test('3-decimal currencies', () {
      expect(CurrencyMeta.decimalsFor('TND'), 3);
      expect(CurrencyMeta.decimalsFor('LYD'), 3);
      expect(CurrencyMeta.minorUnitsPer('TND'), 1000);
    });

    test('0-decimal currencies', () {
      expect(CurrencyMeta.decimalsFor('DJF'), 0);
      expect(CurrencyMeta.decimalsFor('KMF'), 0);
      expect(CurrencyMeta.minorUnitsPer('DJF'), 1);
    });

    test('subdivide-by-5 currencies are treated as 0 decimals', () {
      expect(CurrencyMeta.decimalsFor('MRU'), 0);
      expect(CurrencyMeta.decimalsFor('MGA'), 0);
    });
  });

  group('Money respects the currency exponent', () {
    test('major and formatting use the right number of decimals', () {
      const tnd = Money(minorUnits: 12345, currency: 'TND'); // 12.345
      expect(tnd.major, closeTo(12.345, 1e-9));
      expect(tnd.toString(), 'TND 12.345');

      const djf = Money(minorUnits: 1200, currency: 'DJF'); // 1200
      expect(djf.major, 1200);
      expect(djf.toString(), 'DJF 1200');

      const ngn = Money(minorUnits: 150000, currency: 'NGN'); // 1500.00
      expect(ngn.toString(), 'NGN 1500.00');
    });

    test('fromMajor converts using the exponent', () {
      expect(Money.fromMajor(12.345, 'TND').minorUnits, 12345);
      expect(Money.fromMajor(1200, 'DJF').minorUnits, 1200);
      expect(Money.fromMajor(15, 'NGN').minorUnits, 1500);
    });
  });
}
