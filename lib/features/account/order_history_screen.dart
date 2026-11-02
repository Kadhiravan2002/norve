import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/norve_theme.dart';
import '../orders/order_providers.dart';
import '../orders/order_repository.dart';
import '../products/product.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(customerOrdersProvider);
    return SafeArea(
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _message(
          context,
          'Your orders could not be loaded. Check your sign-in and connection.',
          action: TextButton(
            onPressed: () => ref.invalidate(customerOrdersProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (orders) => orders.isEmpty
            ? _message(
                context,
                'Your order history will appear here after your first order.',
                action: FilledButton(
                  onPressed: () => context.go('/shop'),
                  child: const Text('Continue Shopping'),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width >= 768
                        ? 1050
                        : double.infinity,
                  ),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                          child: Text(
                            'Your Orders',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                      ),
                      SliverList.separated(
                        itemCount: orders.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return Material(
                            color: NorveColors.ivory,
                            child: ListTile(
                              key: ValueKey('customer-order-${order.id}'),
                              onTap: () =>
                                  context.push('/account/orders/${order.id}'),
                              title: Text(
                                order.reference,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${_date(order.createdAt)} · ${order.items.length} items · Cash on Delivery · ${paymentStatusLabel(order.paymentStatus)}',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(formatInr(order.total)),
                                  const SizedBox(height: 4),
                                  Text(
                                    orderStatusLabel(order.status),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _message(BuildContext context, String message, {Widget? action}) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 14), action],
            ],
          ),
        ),
      );

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
