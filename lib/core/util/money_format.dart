import 'package:intl/intl.dart';

import '../models/money.dart';

/// Formats [Money] for display using the currency's own decimal exponent
/// (never assumes two decimals) with thousands grouping, e.g. `NGN 1,500.00`,
/// `TND 12.345`, `DJF 1,200`. The currency code is always shown — amounts are
/// never rendered bare.
String formatMoney(Money money) {
  final pattern = money.decimals > 0 ? '#,##0.${'0' * money.decimals}' : '#,##0';
  return '${money.currency} ${NumberFormat(pattern).format(money.major)}';
}
