import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/models/enums.dart';

void main() {
  group('Order lifecycle state machine (v2 §8 B1)', () {
    test('happy path transitions are allowed', () {
      expect(
        OrderStatus.awaitingDeliveryQuote
            .canTransitionTo(OrderStatus.awaitingPayment),
        isTrue,
      );
      expect(
        OrderStatus.awaitingPayment.canTransitionTo(OrderStatus.confirmed),
        isTrue,
      );
      expect(OrderStatus.confirmed.canTransitionTo(OrderStatus.shipped), isTrue);
      expect(OrderStatus.shipped.canTransitionTo(OrderStatus.delivered), isTrue);
      expect(
          OrderStatus.delivered.canTransitionTo(OrderStatus.completed), isTrue);
    });

    test('illegal jumps are rejected', () {
      // Cannot confirm before a delivery quote.
      expect(
        OrderStatus.awaitingDeliveryQuote.canTransitionTo(OrderStatus.confirmed),
        isFalse,
      );
      // Cannot ship before payment.
      expect(
        OrderStatus.awaitingPayment.canTransitionTo(OrderStatus.shipped),
        isFalse,
      );
      // Cannot skip shipping straight to delivered.
      expect(
        OrderStatus.confirmed.canTransitionTo(OrderStatus.delivered),
        isFalse,
      );
    });

    test('cancellation cutoff is at shipping', () {
      expect(OrderStatus.awaitingDeliveryQuote.buyerCanCancel, isTrue);
      expect(OrderStatus.awaitingPayment.buyerCanCancel, isTrue);
      expect(OrderStatus.confirmed.buyerCanCancel, isTrue);
      // Once shipped (and after), the buyer can no longer cancel.
      expect(OrderStatus.shipped.buyerCanCancel, isFalse);
      expect(OrderStatus.delivered.buyerCanCancel, isFalse);

      expect(OrderStatus.confirmed.canTransitionTo(OrderStatus.cancelled), isTrue);
      expect(OrderStatus.shipped.canTransitionTo(OrderStatus.cancelled), isFalse);
    });

    test('terminal states allow no transitions', () {
      for (final s in [
        OrderStatus.completed,
        OrderStatus.cancelled,
        OrderStatus.refunded,
      ]) {
        expect(s.isTerminal, isTrue);
        for (final next in OrderStatus.values) {
          expect(s.canTransitionTo(next), isFalse);
        }
      }
    });
  });
}
