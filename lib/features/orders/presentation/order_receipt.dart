import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/money.dart';
import '../../../core/models/order.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/money_format.dart';

/// Whether [order] has taken money, so a receipt makes sense (SA-046).
bool hasReceipt(ShopOrder order) => const {
      PaymentStatus.captured,
      PaymentStatus.partiallyRefunded,
      PaymentStatus.refunded,
    }.contains(order.paymentStatus);

String _date(DateTime? d) {
  if (d == null) return '-';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

/// The receipt as plain text, for copying or sharing.
String receiptText(ShopOrder o) {
  final b = StringBuffer()
    ..writeln('Shop Afrik receipt')
    ..writeln('Order: ${o.id}')
    ..writeln('Placed: ${_date(o.createdAt)}')
    ..writeln('Payment: ${o.paymentMethod == PaymentMethod.payOnDelivery ? 'Pay on delivery' : 'Pay now'}'
        ' (${o.paymentStatus.name})');
  if (o.qrWalletTxnId != null) b.writeln('QR Wallet ref: ${o.qrWalletTxnId}');
  b.writeln();
  for (final i in o.items) {
    b.writeln('${i.quantity} x ${i.title}  ${formatMoney(i.unitPrice)} each  '
        '${formatMoney(i.lineTotal)}');
    if (i.refundedQuantity > 0) b.writeln('   ${i.refundedQuantity} refunded');
  }
  b
    ..writeln()
    ..writeln('Subtotal: ${formatMoney(o.subtotal)}')
    ..writeln('Payment fee: ${formatMoney(o.paymentFee)}');
  if (o.deliveryFee != null) b.writeln('Delivery: ${formatMoney(o.deliveryFee!)}');
  b.writeln('Total paid: ${formatMoney(o.total)}');
  final refunded = _refunded(o);
  if (refunded != null) b.writeln('Refunded: ${formatMoney(refunded)}');
  if (o.deliveryLocation != null) {
    b
      ..writeln()
      ..writeln('Deliver to: ${o.deliveryLocation!.recipientName}, '
          '${o.deliveryLocation!.summary}');
  }
  return b.toString();
}

Money? _refunded(ShopOrder o) {
  final minor = o.items.fold<int>(
      0, (sum, i) => sum + i.unitPrice.minorUnits * i.refundedQuantity);
  return minor == 0
      ? null
      : Money(minorUnits: minor, currency: o.subtotal.currency);
}

/// Shows the receipt for [order] in a sheet with a copy button.
Future<void> showOrderReceipt(BuildContext context, ShopOrder order) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Receipt',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              IconButton(
                tooltip: 'Copy receipt',
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(
                      ClipboardData(text: receiptText(order)));
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Receipt copied.')));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(receiptText(order),
              style: const TextStyle(height: 1.5)),
          const SizedBox(height: 8),
          const Text(
            'Keep this for your records. Refunds go back to your QR Wallet.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
