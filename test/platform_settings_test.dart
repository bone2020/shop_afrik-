import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/models/platform_settings.dart';

void main() {
  group('PlatformSettings is data-driven by country/currency', () {
    test('seed defaults expose enabled markets and per-currency tiers', () {
      const s = PlatformSettings();
      expect(s.isMarketEnabled('GH'), isTrue);
      expect(s.isMarketEnabled('NG'), isTrue);
      expect(s.marketFor('GH')!.currency, 'GHS');
      expect(s.refundTiersFor('NGN')!.tier1, 50000);
    });

    test('unknown market / currency resolve to null, not a default', () {
      const s = PlatformSettings();
      expect(s.marketFor('ZZ'), isNull);
      expect(s.isMarketEnabled('ZZ'), isFalse);
      expect(s.refundTiersFor('XAF'), isNull);
      expect(s.deliveryFeeFor('ZZ'), isNull);
    });

    test('adding a country is pure config — no code change', () {
      // Simulate an admin adding Kenya via the platform settings document.
      final s = PlatformSettings.fromMap({
        'markets': {
          'KE': {
            'countryCode': 'KE',
            'currency': 'KES',
            'dialCode': '+254',
            'label': 'Kenya',
            'enabled': true,
            'deliveryFeeMinor': 30000,
            'paymentFeeRate': 0.02,
          },
        },
        'refundTiersByCurrency': {
          'KES': {'tier1': 6500, 'tier2': 39000},
        },
      });

      expect(s.isMarketEnabled('KE'), isTrue);
      expect(s.deliveryFeeFor('KE')!.currency, 'KES');
      expect(s.deliveryFeeFor('KE')!.minorUnits, 30000);
      // Per-market payment-fee override beats the global rate.
      expect(s.paymentFeeRateFor('KE'), 0.02);
      expect(s.refundTiersFor('KES')!.tier2, 39000);
    });

    test('payment fee falls back to global when no market override', () {
      const s = PlatformSettings(paymentFeeRate: 0.015);
      expect(s.paymentFeeRateFor('GH'), 0.015);
    });
  });
}
