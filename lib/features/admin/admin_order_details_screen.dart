import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/norve_theme.dart';
import '../orders/order_providers.dart';
import '../orders/order_repository.dart';
import '../products/product.dart';

class AdminOrderDetailsScreen extends ConsumerStatefulWidget {
  const AdminOrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<AdminOrderDetailsScreen> createState() =>
      _AdminOrderDetailsScreenState();
}

class _AdminOrderDetailsScreenState
    extends ConsumerState<AdminOrderDetailsScreen> {
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminOrderProvider(widget.orderId));
    return SafeArea(
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Order details could not be loaded. Check administrator access and the database connection.',
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(adminOrderProvider(widget.orderId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (order) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.reference,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_date(order.createdAt)} · ${orderStatusLabel(order.status)}',
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NorveColors.white,
                        border: Border.all(color: NorveColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 7),
                          Text(order.customerName),
                          Text(order.email),
                          Text(order.phone),
                          const SizedBox(height: 12),
                          Text(
                            'Delivery address',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 7),
                          Text(order.addressLabel),
                          Text(
                            '${order.addressLine1}\n${order.streetArea.isEmpty ? order.addressLine2 : order.streetArea}${order.landmark.isEmpty ? '' : '\nLandmark: ${order.landmark}'}\n${order.city}, ${order.region} ${order.postalCode}\n${order.country}',
                          ),
                          const SizedBox(height: 12),
                          Text('Payment method: Cash on Delivery'),
                          Text(
                            'Payment: ${paymentStatusLabel(order.paymentStatus)}',
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        key: const ValueKey('admin-order-error'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      'Update order status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final status in _nextStatuses(order.status))
                          OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => _updateStatus(status),
                            child: _saving
                                ? const SizedBox.square(
                                    dimension: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(orderStatusLabel(status)),
                          ),
                      ],
                    ),
                    if (_nextStatuses(order.status).isEmpty)
                      Text(
                        'This order is in a final status.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: NorveColors.muted),
                      ),
                    const SizedBox(height: 22),
                    if (canCollectCodPayment(order)) ...[
                      FilledButton.icon(
                        key: const ValueKey('collect-cod-payment'),
                        onPressed: _saving ? null : _confirmCollection,
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Mark cash collected'),
                      ),
                      const SizedBox(height: 18),
                    ],
                    Text(
                      'Items',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ),
            SliverList.separated(
              itemCount: order.items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = order.items[index];
                return ListTile(
                  title: Text(item.productName),
                  subtitle: Text(
                    '${productVariantLabel(item.size, item.color).isEmpty ? 'Single option' : productVariantLabel(item.size, item.color)} · Qty ${item.quantity} · ${formatInr(item.unitPrice)} each',
                  ),
                  trailing: Text(formatInr(item.lineTotal)),
                );
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _total('Items subtotal', order.subtotal),
                    _total('Delivery', order.shipping),
                    _total('Tax', order.tax),
                    _total('Order total', order.total, strong: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _nextStatuses(String status) => nextOrderStatuses(status);

  Future<void> _confirmCollection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm cash collection'),
        content: const Text('Confirm that cash was received for this order.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm collection'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _collectPayment();
  }

  Future<void> _collectPayment() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(orderRepositoryProvider).collectCodPayment(widget.orderId);
      ref.invalidate(adminOrderProvider(widget.orderId));
      ref.invalidate(adminOrdersProvider);
      ref.invalidate(adminOrderSummaryProvider);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              'Payment collection could not be recorded. ${error.toString().replaceFirst('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    if (status == 'cancelled') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel this order?'),
          content: const Text(
            'This will cancel the order and restore eligible reserved stock.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep order'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm cancellation'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(orderRepositoryProvider)
          .updateOrderStatus(widget.orderId, status);
      ref.invalidate(adminOrderProvider(widget.orderId));
      ref.invalidate(adminOrdersProvider);
      ref.invalidate(adminOrderSummaryProvider);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              'Status update failed. ${error.toString().replaceFirst('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _total(String label, int amount, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontWeight: strong ? FontWeight.w700 : null),
          ),
        ),
        Text(
          formatInr(amount),
          style: TextStyle(fontWeight: strong ? FontWeight.w700 : null),
        ),
      ],
    ),
  );

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
