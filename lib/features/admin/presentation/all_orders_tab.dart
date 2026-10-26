import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/platform_settings_repository.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/order.dart';
import '../../../core/models/platform_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/callable_error.dart';
import '../../../core/util/money_format.dart';
import '../../orders/presentation/order_status_chip.dart';
import '../data/admin_tools_repository.dart';
import 'paged_admin_list.dart';

enum _PersonKind { buyer, seller }

/// Every order, newest first, filtered by status, market and date, and
/// searchable by order id or by a buyer or seller's email, phone or user id
/// (SA-134).
class AllOrdersTab extends ConsumerStatefulWidget {
  const AllOrdersTab({super.key});

  @override
  ConsumerState<AllOrdersTab> createState() => _AllOrdersTabState();
}

class _AllOrdersTabState extends ConsumerState<AllOrdersTab> {
  final _search = TextEditingController();
  _PersonKind _kind = _PersonKind.buyer;
  OrderStatus? _status;
  String? _market;
  DateTimeRange? _range;
  String? _personId;
  String? _personLabel;
  ShopOrder? _exact;
  String? _message;
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  OrderFilter get _filter => OrderFilter(
        status: _status,
        market: _market,
        buyerId: _kind == _PersonKind.buyer ? _personId : null,
        sellerId: _kind == _PersonKind.seller ? _personId : null,
        from: _range?.start,
        // Include the whole last day.
        to: _range?.end.add(const Duration(days: 1)),
      );

  Future<void> _runSearch() async {
    final q = _search.text.trim();
    setState(() {
      _exact = null;
      _message = null;
      _personId = null;
      _personLabel = null;
    });
    if (q.isEmpty) return;
    final repo = ref.read(adminToolsRepositoryProvider);
    setState(() => _searching = true);
    try {
      // An order id first, unless it is clearly an email or phone number.
      if (!q.contains('@') && !q.startsWith('+')) {
        final order = await repo.getOrder(q);
        if (order != null) {
          setState(() => _exact = order);
          return;
        }
      }
      final user = await repo.findUser(q);
      setState(() {
        if (user == null) {
          _message = 'No order or account matches "$q".';
        } else {
          _personId = user.uid;
          _personLabel = user.label;
        }
      });
    } catch (e) {
      setState(() => _message = callableErrorMessage(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _clearSearch() => setState(() {
        _search.clear();
        _exact = null;
        _message = null;
        _personId = null;
        _personLabel = null;
      });

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _range,
    );
    if (range != null) setState(() => _range = range);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(platformSettingsProvider).valueOrNull ??
        const PlatformSettings();
    final filter = _filter;
    final personSearch = _personId != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        labelText: 'Order id, email, phone or user id',
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                icon: const Icon(Icons.close),
                                onPressed: _clearSearch,
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _runSearch(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Search',
                    onPressed: _searching ? null : _runSearch,
                    icon: const Icon(Icons.search),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SegmentedButton<_PersonKind>(
                      segments: const [
                        ButtonSegment(
                            value: _PersonKind.buyer, label: Text('As buyer')),
                        ButtonSegment(
                            value: _PersonKind.seller,
                            label: Text('As seller')),
                      ],
                      selected: {_kind},
                      onSelectionChanged: (s) =>
                          setState(() => _kind = s.first),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<OrderStatus?>(
                      value: _status,
                      hint: const Text('Any status'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Any status')),
                        for (final s in OrderStatus.values)
                          DropdownMenuItem(
                              value: s, child: Text(orderStatusLabel(s))),
                      ],
                      onChanged: (s) => setState(() => _status = s),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String?>(
                      value: personSearch ? null : _market,
                      hint: const Text('Any market'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Any market')),
                        for (final m in settings.markets.values)
                          DropdownMenuItem(
                              value: m.countryCode, child: Text(m.label)),
                      ],
                      onChanged: personSearch
                          ? null
                          : (m) => setState(() => _market = m),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(_range == null
                          ? 'Any date'
                          : '${_d(_range!.start)} to ${_d(_range!.end)}'),
                    ),
                    if (_range != null)
                      IconButton(
                        tooltip: 'Clear dates',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _range = null),
                      ),
                  ],
                ),
              ),
              if (_searching) const LinearProgressIndicator(),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_message!,
                      style: const TextStyle(color: AppColors.mutedText)),
                ),
              if (personSearch)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      'Orders where $_personLabel is the '
                      '${_kind == _PersonKind.buyer ? 'buyer' : 'seller'}',
                      style: const TextStyle(color: AppColors.mutedText)),
                ),
            ],
          ),
        ),
        Expanded(
          child: _exact != null
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [AdminOrderCard(order: _exact!, initiallyExpanded: true)],
                )
              : PagedAdminList<ShopOrder>(
                  queryKey: filter,
                  load: (cursor) => ref
                      .read(adminToolsRepositoryProvider)
                      .fetchOrders(filter, cursor: cursor),
                  itemBuilder: (_, o) => AdminOrderCard(order: o),
                  emptyText: 'No orders match these filters.',
                ),
        ),
      ],
    );
  }
}

String _d(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final l = d.toLocal();
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}

/// One order with its key facts; expands to show lines, people and money.
class AdminOrderCard extends StatelessWidget {
  const AdminOrderCard(
      {super.key, required this.order, this.initiallyExpanded = false});
  final ShopOrder order;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final o = order;
    const muted = TextStyle(color: AppColors.mutedText, fontSize: 13);
    final sellers = {for (final i in o.items) i.sellerId};

    return Card(
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Row(
          children: [
            Expanded(
              child: Text(o.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Text(formatMoney(o.total),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OrderStatusChip(status: o.status),
              Text(
                [
                  o.deliveryLocation?.market,
                  if (o.createdAt != null) _d(o.createdAt!),
                ].whereType<String>().join(' · '),
                style: muted,
              ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final i in o.items)
            Text(
                '${i.quantity} × ${i.title}  ${formatMoney(i.unitPrice)}'
                '${i.refundedQuantity > 0 ? '  (${i.refundedQuantity} refunded)' : ''}'),
          const SizedBox(height: 8),
          Text('Buyer: ${o.buyerId}', style: muted),
          Text('Sellers: ${sellers.join(', ')}', style: muted),
          if (o.courierId != null) Text('Courier: ${o.courierId}', style: muted),
          if (o.deliveryLocation != null)
            Text(
                'Deliver to: ${o.deliveryLocation!.recipientName}, '
                '${o.deliveryLocation!.city}',
                style: muted),
          Text(
              'Payment: ${o.paymentStatus.name} · Delivery: '
              '${o.deliveryStatus.name} · Settlement: ${o.settlementStatus.name}',
              style: muted),
        ],
      ),
    );
  }
}
