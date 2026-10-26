import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/models/firestore_dates.dart';
import 'package:shop_afrik/core/models/order.dart';

void main() {
  test('reads Timestamps written by Cloud Functions', () {
    final when = DateTime.utc(2026, 11, 3, 12);
    expect(readDate(Timestamp.fromDate(when))?.toUtc(), when);
  });

  test('reads ISO strings and tolerates missing or bad values', () {
    expect(readDate('2026-11-03T12:00:00.000Z'), DateTime.utc(2026, 11, 3, 12));
    expect(readDate(null), isNull);
    expect(readDate('not a date'), isNull);
    expect(readDate(42), isNull);
  });

  test('an order written by the server parses instead of throwing', () {
    final order = ShopOrder.fromMap('o1', {
      'buyerId': 'b1',
      'status': 'delivered',
      'subtotal': const {'minorUnits': 1000, 'currency': 'GHS'},
      'paymentFee': const {'minorUnits': 15, 'currency': 'GHS'},
      'total': const {'minorUnits': 1015, 'currency': 'GHS'},
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 1)),
      'settlementDueAt': Timestamp.fromDate(DateTime.utc(2026, 11, 9)),
    });
    expect(order.settlementDueAt?.toUtc(), DateTime.utc(2026, 11, 9));
  });
}
