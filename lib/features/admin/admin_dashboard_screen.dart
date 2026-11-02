import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/norve_theme.dart';
import '../products/product_catalog_provider.dart';
import '../products/widgets/catalog_state_notice.dart';
import '../orders/order_providers.dart';
import 'admin_metrics.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(productCatalogProvider);
    final status = ref.watch(catalogLoadStateProvider);
    final orderSummary = ref.watch(adminOrderSummaryProvider);
    final lowStock = catalog
        .where((product) => product.stockQuantity <= lowStockThreshold)
        .toList();
    final dataAvailable =
        status.phase == CatalogPhase.live ||
        status.phase == CatalogPhase.development;
    final metrics = [
      ('Total products', dataAvailable ? '${catalog.length}' : '—'),
      (
        'Units in stock',
        dataAvailable
            ? '${catalog.fold<int>(0, (sum, product) => sum + product.stockQuantity)}'
            : '—',
      ),
      ('Low-stock products', dataAvailable ? '${lowStock.length}' : '—'),
    ];
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = (screenWidth >= 768 ? screenWidth - 82 : screenWidth).clamp(
      0.0,
      1440.0,
    );
    final columns = width >= 900
        ? 3
        : width >= 520
        ? 2
        : 1;
    final cardWidth = (width - 40 - ((columns - 1) * 12)) / columns;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: CatalogStateNotice()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Dashboard',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Catalogue and inventory overview',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: NorveColors.muted),
                  ),
                  const SizedBox(height: 19),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final metric in metrics)
                        SizedBox(
                          width: cardWidth,
                          child: AdminMetricCard(
                            label: metric.$1,
                            value: metric.$2,
                            caption: dataAvailable
                                ? 'Current catalogue data'
                                : 'Unavailable while disconnected',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Orders Overview',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: NorveColors.white,
                      border: Border.all(color: NorveColors.line),
                    ),
                    child: orderSummary.when(
                      loading: () => const LinearProgressIndicator(
                        color: NorveColors.charcoal,
                      ),
                      error: (error, stack) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order metrics could not be loaded. Check administrator access and the connection.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: NorveColors.muted,
                                  height: 1.5,
                                ),
                          ),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(adminOrderSummaryProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                      data: (summary) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total orders · ${summary.totalOrders}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pending fulfillment · ${summary.pendingOrders}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: NorveColors.muted),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Orders are paid by Cash on Delivery. Collection is confirmed separately.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: NorveColors.muted,
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Low stock',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/admin/inventory'),
                        child: const Text('View inventory'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!dataAvailable)
            const SliverToBoxAdapter(child: SizedBox(height: 12))
          else if (lowStock.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No products meet the low-stock threshold.'),
              ),
            )
          else
            SliverList.builder(
              itemCount: lowStock.length,
              itemBuilder: (context, index) {
                final product = lowStock[index];
                return Material(
                  color: NorveColors.ivory,
                  child: ListTile(
                    onTap: () => context.go('/admin/inventory'),
                    title: Text(product.name),
                    subtitle: Text(
                      product.isActive ? 'Active product' : 'Inactive product',
                    ),
                    trailing: AdminStatusChip(
                      label: '${product.stockQuantity} units',
                    ),
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 22)),
        ],
      ),
    );
  }
}
