import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/norve_theme.dart';
import '../orders/order_providers.dart';
import '../orders/order_repository.dart';
import '../products/product.dart';
import 'admin_metrics.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  final _search = TextEditingController();
  String _status = 'All statuses';
  String _payment = 'All payment statuses';
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(adminOrdersProvider);
    return SafeArea(
      child: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _stateMessage(
          context,
          'Orders could not be loaded. Check administrator access and the database connection.',
          action: TextButton(
            onPressed: () => ref.invalidate(adminOrdersProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (allOrders) {
          final visible = allOrders.where((order) {
            final text =
                '${order.reference} ${order.email} ${order.customerName} ${order.items.map((item) => item.productName).join(' ')}'
                    .toLowerCase();
            final queryMatch = text.contains(_query.toLowerCase());
            final statusMatch =
                _status == 'All statuses' ||
                orderStatusLabel(order.status) == _status;
            final paymentMatch =
                _payment == 'All payment statuses' ||
                paymentStatusLabel(order.paymentStatus) == _payment;
            return queryMatch && statusMatch && paymentMatch;
          }).toList();
          return CustomScrollView(
            key: const ValueKey('admin-orders-scroll'),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Orders',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${allOrders.length} persisted orders',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: NorveColors.muted),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final search = TextField(
                            controller: _search,
                            onChanged: (value) =>
                                setState(() => _query = value),
                            decoration: const InputDecoration(
                              hintText: 'Search reference, customer or product',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          );
                          final filter = DropdownButtonFormField<String>(
                            initialValue: _status,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'All statuses',
                                child: Text('All statuses'),
                              ),
                              DropdownMenuItem(
                                value: 'Pending',
                                child: Text('Pending'),
                              ),
                              DropdownMenuItem(
                                value: 'Confirmed',
                                child: Text('Confirmed'),
                              ),
                              DropdownMenuItem(
                                value: 'Processing',
                                child: Text('Processing'),
                              ),
                              DropdownMenuItem(
                                value: 'Shipped',
                                child: Text('Shipped'),
                              ),
                              DropdownMenuItem(
                                value: 'Out for Delivery',
                                child: Text('Out for Delivery'),
                              ),
                              DropdownMenuItem(
                                value: 'Delivered',
                                child: Text('Delivered'),
                              ),
                              DropdownMenuItem(
                                value: 'Cancelled',
                                child: Text('Cancelled'),
                              ),
                            ],
                            onChanged: (value) => setState(
                              () => _status = value ?? 'All statuses',
                            ),
                          );
                          final paymentFilter = DropdownButtonFormField<String>(
                            initialValue: _payment,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Payment',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'All payment statuses',
                                child: Text('All payments'),
                              ),
                              DropdownMenuItem(
                                value: 'Pending collection',
                                child: Text('Pending collection'),
                              ),
                              DropdownMenuItem(
                                value: 'Cash collected',
                                child: Text('Cash collected'),
                              ),
                            ],
                            onChanged: (value) => setState(
                              () => _payment = value ?? 'All payment statuses',
                            ),
                          );
                          if (constraints.maxWidth < 560) {
                            return Column(
                              children: [
                                search,
                                const SizedBox(height: 10),
                                filter,
                                const SizedBox(height: 10),
                                paymentFilter,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: search),
                              const SizedBox(width: 12),
                              SizedBox(width: 190, child: filter),
                              const SizedBox(width: 10),
                              SizedBox(width: 190, child: paymentFilter),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (allOrders.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('No orders have been placed.')),
                )
              else if (visible.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('No orders match these filters.')),
                )
              else
                SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final order = visible[index];
                    return Material(
                      color: NorveColors.ivory,
                      child: ListTile(
                        key: ValueKey('admin-order-${order.id}'),
                        onTap: () => context.push('/admin/orders/${order.id}'),
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text(
                          order.reference,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${order.customerName} · ${_date(order.createdAt)} · ${paymentStatusLabel(order.paymentStatus)}',
                        ),
                        trailing: SizedBox(
                          width: 88,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatInr(order.total),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: AdminStatusChip(
                                  label: orderStatusLabel(order.status),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  Widget _stateMessage(
    BuildContext context,
    String message, {
    Widget? action,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          ?action,
        ],
      ),
    ),
  );

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
