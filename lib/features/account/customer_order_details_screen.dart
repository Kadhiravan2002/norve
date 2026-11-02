import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/norve_theme.dart';
import '../orders/order_providers.dart';
import '../orders/order_repository.dart';
import '../products/product.dart';

class CustomerOrderDetailsScreen extends ConsumerWidget {
  const CustomerOrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(customerOrderProvider(orderId));
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
                  'This order could not be loaded. Verify your sign-in and try again.',
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(customerOrderProvider(orderId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (order) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width >= 768
                  ? 1100
                  : double.infinity,
            ),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.reference,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_date(order.createdAt)} · ${orderStatusLabel(order.status)}',
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Cash on Delivery · ${paymentStatusLabel(order.paymentStatus)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: NorveColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList.separated(
                  itemCount: order.items.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery address',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(order.addressLabel),
                        Text(
                          '${order.customerName}\n${order.addressLine1}\n${order.streetArea.isEmpty ? order.addressLine2 : order.streetArea}${order.landmark.isEmpty ? '' : '\nLandmark: ${order.landmark}'}\n${order.city}, ${order.region} ${order.postalCode}\n${order.country}\n${order.phone}',
                        ),
                        const Divider(height: 28),
                        _total('Items subtotal', order.subtotal),
                        _total('Delivery', order.shipping),
                        _total('Tax', order.tax),
                        _total('Total', order.total, strong: true),
                        const SizedBox(height: 12),
                        Text(
                          'Payment summary',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        const Text('Cash on Delivery'),
                        Text(
                          'Payment status: ${paymentStatusLabel(order.paymentStatus)}',
                        ),
                        if (order.paymentStatus == 'pending')
                          const Text(
                            'Cash is due when the order is delivered.',
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _total(String label, int value, {bool strong = false}) => Padding(
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
          formatInr(value),
          style: TextStyle(fontWeight: strong ? FontWeight.w700 : null),
        ),
      ],
    ),
  );

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
