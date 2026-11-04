import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../orders/order_providers.dart';
import '../orders/order_repository.dart';
import '../products/product.dart';
import '../products/product_catalog_provider.dart';
import '../products/widgets/catalog_state_notice.dart';
import 'admin_metrics.dart';
import 'widgets/admin_widgets.dart';

/// Redesigned NORVÉ Administration Dashboard.
///
/// Adapted from the primary reference layout (Template 1) into an editorial,
/// luxury fashion-commerce administrative experience. Displays real-time
/// catalogue KPIs, sales and order distribution, latest customer orders,
/// financial settlement summaries, and operational alerts.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(productCatalogProvider);
    final status = ref.watch(catalogLoadStateProvider);
    final ordersAsync = ref.watch(adminOrdersProvider);
    final orderSummaryAsync = ref.watch(adminOrderSummaryProvider);

    final dataAvailable =
        status.phase == CatalogPhase.live ||
        status.phase == CatalogPhase.development;

    final lowStock = catalog
        .where((product) => product.stockQuantity <= lowStockThreshold)
        .toList();

    final totalStock = catalog.fold<int>(
      0,
      (sum, product) => sum + product.stockQuantity,
    );

    final activeProductsCount =
        catalog.where((product) => product.isActive).length;

    return SafeArea(
      child: CustomScrollView(
        key: const ValueKey('admin-dashboard-scroll'),
        slivers: [
          const SliverToBoxAdapter(child: CatalogStateNotice()),
          SliverToBoxAdapter(
            child: AdminPageHeader(
              title: 'Admin Dashboard',
              subtitle:
                  'Operational summary of catalogue performance, real-time inventory and customer orders.',
              actions: [
                AdminButton.secondary(
                  label: 'View Inventory',
                  icon: const Icon(Icons.stacked_bar_chart_outlined, size: 16),
                  onPressed: () => context.go('/admin/inventory'),
                ),
                AdminButton.primary(
                  label: 'Add product',
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () => context.push('/admin/products/new'),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: AdminMotion.duration(context, AdminMotion.component),
              curve: AdminMotion.curveFast,
              builder: (context, opacity, child) =>
                  Opacity(opacity: opacity, child: child!),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // KPI Metric Cards Row
                  _buildKpiRow(
                    context: context,
                    dataAvailable: dataAvailable,
                    catalogCount: catalog.length,
                    activeProductsCount: activeProductsCount,
                    totalStock: totalStock,
                    lowStockCount: lowStock.length,
                    orderSummaryAsync: orderSummaryAsync,
                    ordersAsync: ordersAsync,
                  ),
                  const SizedBox(height: 24),

                  // Main Two-Column Layout (Responsive)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 760;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column (Analytics & Recent Orders)
                            Expanded(
                              flex: 6,
                              child: Column(
                                children: [
                                  _buildSalesAndOrdersCard(
                                    context,
                                    ordersAsync,
                                    ref,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildRecentOrdersCard(
                                    context,
                                    ordersAsync,
                                    ref,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            // Right Column (Financial Overview & Operational Alerts)
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  _buildFinancialOverviewCard(
                                    context,
                                    ordersAsync,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildOperationalAlertsCard(
                                    context,
                                    lowStock,
                                    ordersAsync,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildQuickActionsCard(context),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      // Compact / Stacked Layout for Tablet Portrait & Mobile
                      final isTabletPortrait = constraints.maxWidth >= 500;
                      return Column(
                        children: [
                          _buildSalesAndOrdersCard(
                            context,
                            ordersAsync,
                            ref,
                          ),
                          const SizedBox(height: 20),
                          _buildRecentOrdersCard(
                            context,
                            ordersAsync,
                            ref,
                          ),
                          const SizedBox(height: 20),
                          _buildFinancialOverviewCard(
                            context,
                            ordersAsync,
                          ),
                          const SizedBox(height: 20),
                          if (isTabletPortrait)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildOperationalAlertsCard(
                                    context,
                                    lowStock,
                                    ordersAsync,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildQuickActionsCard(context),
                                ),
                              ],
                            )
                          else ...[
                            _buildOperationalAlertsCard(
                              context,
                              lowStock,
                              ordersAsync,
                            ),
                            const SizedBox(height: 20),
                            _buildQuickActionsCard(context),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KPI Metrics Row
  // ---------------------------------------------------------------------------
  Widget _buildKpiRow({
    required BuildContext context,
    required bool dataAvailable,
    required int catalogCount,
    required int activeProductsCount,
    required int totalStock,
    required int lowStockCount,
    required AsyncValue<AdminOrderSummary> orderSummaryAsync,
    required AsyncValue<List<OrderRecord>> ordersAsync,
  }) {
    final totalOrdersText = orderSummaryAsync.when(
      data: (s) => '${s.totalOrders}',
      loading: () => '...',
      error: (err, stack) =>
          ordersAsync.asData?.value.length.toString() ?? '—',
    );

    final pendingOrdersCount = orderSummaryAsync.when(
      data: (s) => s.pendingOrders,
      loading: () => 0,
      error: (err, stack) =>
          ordersAsync.asData?.value
              .where((o) => o.status.toLowerCase() == 'pending')
              .length ??
          0,
    );

    final kpis = [
      (
        label: 'Total Products',
        value: dataAvailable ? '$catalogCount' : '—',
        caption: dataAvailable
            ? '$activeProductsCount active in catalogue'
            : 'Catalogue disconnected',
        icon: Icons.inventory_2_outlined,
        isAlert: false,
        isHealthy: false,
      ),
      (
        label: 'Units in Stock',
        value: dataAvailable ? _formatCurrency(totalStock) : '—',
        caption: 'Across all active variants',
        icon: Icons.check_circle_outline,
        isAlert: false,
        isHealthy: false,
      ),
      (
        label: 'Total Orders',
        value: totalOrdersText,
        caption: '$pendingOrdersCount pending fulfillment',
        icon: Icons.receipt_long_outlined,
        isAlert: false,
        isHealthy: false,
      ),
      (
        label: 'Low-Stock Products',
        value: dataAvailable ? '$lowStockCount' : '—',
        caption: lowStockCount > 0
            ? 'Stock <= $lowStockThreshold units'
            : 'Inventory levels optimal',
        icon: lowStockCount > 0
            ? Icons.warning_amber_outlined
            : Icons.check_circle_outline,
        isAlert: lowStockCount > 0,
        isHealthy: dataAvailable && lowStockCount == 0,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isWide = screenWidth >= 780;
        final isMobile = screenWidth < 500;
        final spacing = isMobile ? AdminSpacing.md : 16.0;

        Widget buildCard(({
          String caption,
          IconData icon,
          bool isAlert,
          bool isHealthy,
          String label,
          String value,
        }) kpi) {
          return _KpiMetricCard(
            label: kpi.label,
            value: kpi.value,
            caption: kpi.caption,
            icon: kpi.icon,
            isAlert: kpi.isAlert,
            isHealthy: kpi.isHealthy,
            isCompact: isMobile,
          );
        }

        if (isWide) {
          return Row(
            children: [
              for (int i = 0; i < kpis.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(child: buildCard(kpis[i])),
              ],
            ],
          );
        }

        // 2x2 grid for tablet portrait and all mobile viewports (matches Categories layout)
        return Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: buildCard(kpis[0])),
                  SizedBox(width: spacing),
                  Expanded(child: buildCard(kpis[1])),
                ],
              ),
            ),
            SizedBox(height: spacing),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: buildCard(kpis[2])),
                  SizedBox(width: spacing),
                  Expanded(child: buildCard(kpis[3])),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Sales & Orders Overview Card
  // ---------------------------------------------------------------------------
  Widget _buildSalesAndOrdersCard(
    BuildContext context,
    AsyncValue<List<OrderRecord>> ordersAsync,
    WidgetRef ref,
  ) {
    return AdminCard(
      title: 'Sales & Orders Overview',
      subtitle: 'Order distribution and fulfillment lifecycle',
      action: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AdminColors.surfaceSubtle,
          border: AdminBorders.subtle,
          borderRadius: AdminRadii.radiusSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AdminColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Real-Time Store Data',
              style: AdminTypography.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: AdminColors.charcoal,
              ),
            ),
          ],
        ),
      ),
      child: ordersAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: AdminLoading(message: 'Loading order metrics...'),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order metrics could not be loaded. Check administrator access and database connection.',
                style: AdminTypography.body.copyWith(color: AdminColors.muted),
              ),
              const SizedBox(height: 12),
              AdminButton.secondary(
                label: 'Retry Connection',
                onPressed: () => ref.invalidate(adminOrdersProvider),
              ),
            ],
          ),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: AdminEmptyState(
                icon: Icons.bar_chart_outlined,
                title: 'No Orders Placed Yet',
                message:
                    'Order distribution and fulfillment performance will visualize here once customers place orders.',
              ),
            );
          }

          final activeOrders = orders
              .where((o) => o.status.toLowerCase() != 'cancelled')
              .toList();

          final grossRevenue = activeOrders.fold<int>(
            0,
            (sum, order) => sum + order.total,
          );
          final avgOrderValue = activeOrders.isEmpty
              ? 0
              : (grossRevenue / activeOrders.length).round();

          // Calculate counts by lifecycle status
          final pendingCount = orders
              .where((o) => o.status.toLowerCase() == 'pending')
              .length;
          final confirmedCount = orders
              .where((o) => o.status.toLowerCase() == 'confirmed')
              .length;
          final dispatchedCount = orders
              .where((o) =>
                  o.status.toLowerCase() == 'dispatched' ||
                  o.status.toLowerCase().contains('delivery'))
              .length;
          final deliveredCount = orders
              .where((o) => o.status.toLowerCase() == 'delivered')
              .length;
          final cancelledCount = orders
              .where((o) => o.status.toLowerCase() == 'cancelled')
              .length;

          final statusBreakdown = [
            (
              label: 'Placed (Pending)',
              count: pendingCount,
              color: AdminColors.warning,
            ),
            (
              label: 'Confirmed',
              count: confirmedCount,
              color: AdminColors.neutralGrey,
            ),
            (
              label: 'Out for Delivery',
              count: dispatchedCount,
              color: AdminColors.charcoal,
            ),
            (
              label: 'Delivered',
              count: deliveredCount,
              color: AdminColors.success,
            ),
            (
              label: 'Cancelled',
              count: cancelledCount,
              color: AdminColors.error,
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary stats header
              Row(
                children: [
                  Expanded(
                    child: _MiniSummaryTile(
                      label: 'GROSS ORDER VALUE',
                      value: '₹${_formatCurrency(grossRevenue)}',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: AdminColors.line,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  Expanded(
                    child: _MiniSummaryTile(
                      label: 'AVG. ORDER VALUE',
                      value: '₹${_formatCurrency(avgOrderValue)}',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: AdminColors.line,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  Expanded(
                    child: _MiniSummaryTile(
                      label: 'TOTAL TRANSACTIONS',
                      value: '${orders.length}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(height: 1, thickness: 1, color: AdminColors.line),
              const SizedBox(height: 20),

              Text(
                'ORDER LIFECYCLE DISTRIBUTION',
                style: AdminTypography.tableHeader,
              ),
              const SizedBox(height: 14),

              // Visual Distribution Bars
              for (final item in statusBreakdown) ...[
                _StatusBarRow(
                  label: item.label,
                  count: item.count,
                  total: orders.length,
                  barColor: item.color,
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recent Orders Table Card
  // ---------------------------------------------------------------------------
  Widget _buildRecentOrdersCard(
    BuildContext context,
    AsyncValue<List<OrderRecord>> ordersAsync,
    WidgetRef ref,
  ) {
    return AdminCard(
      title: 'Recent Orders',
      subtitle: 'Latest transactions placed on the boutique',
      action: AdminButton.ghost(
        label: 'View all orders',
        icon: const Icon(Icons.arrow_forward, size: 14),
        onPressed: () => context.go('/admin/orders'),
      ),
      padding: EdgeInsets.zero,
      child: ordersAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: AdminLoading(message: 'Loading recent orders...'),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Unable to load recent orders.',
            style: AdminTypography.body.copyWith(color: AdminColors.muted),
          ),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: AdminEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No Orders to Display',
                message:
                    'When customers place orders, the latest records will be listed here.',
              ),
            );
          }

          final recentOrders = orders.take(6).toList();

          return Column(
            children: [
              AdminTableHeader(
                children: const [
                  AdminTableHeaderCell(label: 'Order ID', flex: 3),
                  AdminTableHeaderCell(label: 'Customer', flex: 4),
                  AdminTableHeaderCell(label: 'Date', flex: 2),
                  AdminTableHeaderCell(
                    label: 'Total',
                    flex: 2,
                    alignment: Alignment.centerRight,
                  ),
                  AdminTableHeaderCell(
                    label: 'Status',
                    flex: 3,
                    alignment: Alignment.centerRight,
                  ),
                ],
              ),
              for (var i = 0; i < recentOrders.length; i++) ...[
                _buildOrderRow(
                  context,
                  recentOrders[i],
                  showDivider: i < recentOrders.length - 1,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderRow(
    BuildContext context,
    OrderRecord order, {
    required bool showDivider,
  }) {
    final statusLabel = orderStatusLabel(order.status);
    final badgeVariant = _statusBadgeVariant(order.status);
    final customerDisplay = order.customerName.trim().isNotEmpty
        ? order.customerName.trim()
        : order.email;

    return AdminTableRow(
      onTap: () => context.go('/admin/orders/${order.id}'),
      showDivider: showDivider,
      children: [
        AdminTableCell(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              '#${order.reference}',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AdminTypography.bodyBold.copyWith(
                color: AdminColors.charcoal,
              ),
            ),
          ),
        ),
        AdminTableCell(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              customerDisplay,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AdminTypography.body,
            ),
          ),
        ),
        AdminTableCell(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              _formatDate(order.createdAt),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AdminTypography.caption,
            ),
          ),
        ),
        AdminTableCell(
          flex: 2,
          alignment: Alignment.centerRight,
          child: Text(
            '₹${_formatCurrency(order.total)}',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: AdminTypography.bodyBold,
          ),
        ),
        AdminTableCell(
          flex: 3,
          alignment: Alignment.centerRight,
          child: AdminBadge(
            label: statusLabel,
            variant: badgeVariant,
            showDot: true,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Financial Overview Card (Right Column)
  // ---------------------------------------------------------------------------
  Widget _buildFinancialOverviewCard(
    BuildContext context,
    AsyncValue<List<OrderRecord>> ordersAsync,
  ) {
    return AdminCard(
      title: 'Settlement Overview',
      subtitle: 'Cash on Delivery settlement tracking',
      child: ordersAsync.when(
        loading: () => const AdminLoading(padding: EdgeInsets.all(16)),
        error: (err, stack) => Text(
          'Financial summary unavailable.',
          style: AdminTypography.caption,
        ),
        data: (orders) {
          final activeOrders = orders
              .where((o) => o.status.toLowerCase() != 'cancelled')
              .toList();
          final gross = activeOrders.fold<int>(0, (sum, o) => sum + o.total);
          final collected = activeOrders
              .where((o) => o.paymentStatus.toLowerCase() == 'collected')
              .fold<int>(0, (sum, o) => sum + o.total);
          final pending = activeOrders
              .where((o) => o.paymentStatus.toLowerCase() == 'pending')
              .fold<int>(0, (sum, o) => sum + o.total);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetricRowItem(
                label: 'Gross Order Value',
                value: '₹${_formatCurrency(gross)}',
                caption: 'Total value of ${activeOrders.length} active orders',
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1, color: AdminColors.line),
              const SizedBox(height: 12),
              _MetricRowItem(
                label: 'Collected Cash on Delivery',
                value: '₹${_formatCurrency(collected)}',
                caption: 'Settled upon confirmed delivery',
                textColor: AdminColors.success,
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1, color: AdminColors.line),
              const SizedBox(height: 12),
              _MetricRowItem(
                label: 'Pending Collection',
                value: '₹${_formatCurrency(pending)}',
                caption: 'In transit or awaiting dispatch',
                textColor: pending > 0
                    ? AdminColors.warning
                    : AdminColors.charcoal,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AdminColors.surfaceSubtle,
                  borderRadius: AdminRadii.radiusSm,
                  border: AdminBorders.subtle,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AdminColors.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Orders are paid via Cash on Delivery. Cash collection is recorded when orders are delivered.',
                        style: AdminTypography.caption.copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Operational Alerts Panel (Right Column)
  // ---------------------------------------------------------------------------
  Widget _buildOperationalAlertsCard(
    BuildContext context,
    List<Product> lowStock,
    AsyncValue<List<OrderRecord>> ordersAsync,
  ) {
    final pendingOrders = ordersAsync.asData?.value
            .where((o) => o.status.toLowerCase() == 'pending')
            .toList() ??
        [];

    final hasAlerts = lowStock.isNotEmpty || pendingOrders.isNotEmpty;

    return AdminCard(
      title: 'Operational Alerts',
      subtitle: 'Items requiring management attention',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lowStock.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminColors.warningBg,
                border: Border.all(color: AdminColors.warningBorder),
                borderRadius: AdminRadii.radiusSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: AdminColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${lowStock.length} Low-Stock Products',
                        style: AdminTypography.label.copyWith(
                          color: AdminColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lowStock
                        .take(3)
                        .map((p) => '${p.name} (${p.stockQuantity})')
                        .join(', '),
                    style: AdminTypography.caption.copyWith(
                      color: AdminColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AdminButton.secondary(
                      label: 'Restock Inventory',
                      size: AdminButtonSize.sm,
                      onPressed: () => context.go('/admin/inventory'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (pendingOrders.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminColors.infoBg,
                border: Border.all(color: AdminColors.infoBorder),
                borderRadius: AdminRadii.radiusSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.pending_actions_outlined,
                        size: 16,
                        color: AdminColors.charcoal,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${pendingOrders.length} Orders Awaiting Dispatch',
                        style: AdminTypography.label.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Customer orders placed and waiting for fulfillment.',
                    style: AdminTypography.caption,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AdminButton.secondary(
                      label: 'Fulfill Orders',
                      size: AdminButtonSize.sm,
                      onPressed: () => context.go('/admin/orders'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (!hasAlerts) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AdminColors.successBg,
                border: Border.all(color: AdminColors.successBorder),
                borderRadius: AdminRadii.radiusSm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: AdminColors.success,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All systems operational. No stock alerts or pending backlogs.',
                      style: AdminTypography.caption.copyWith(
                        color: AdminColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Quick Actions Card (Right Column)
  // ---------------------------------------------------------------------------
  Widget _buildQuickActionsCard(BuildContext context) {
    final actions = [
      (
        title: 'Add New Product',
        subtitle: 'Create boutique product & upload assets',
        icon: Icons.add_circle_outline,
        path: '/admin/products/new',
      ),
      (
        title: 'Review Stock & Inventory',
        subtitle: 'Adjust variant inventory counts',
        icon: Icons.stacked_bar_chart_outlined,
        path: '/admin/inventory',
      ),
      (
        title: 'Manage Categories',
        subtitle: 'Organize boutique collection hierarchy',
        icon: Icons.category_outlined,
        path: '/admin/categories',
      ),
    ];

    return AdminCard(
      title: 'Quick Actions',
      subtitle: 'Frequent boutique management workflows',
      child: Column(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            InkWell(
              onTap: () => context.go(actions[i].path),
              borderRadius: AdminRadii.radiusSm,
              hoverColor: AdminColors.surfaceSubtle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AdminColors.surfaceSubtle,
                        border: AdminBorders.subtle,
                        borderRadius: AdminRadii.radiusSm,
                      ),
                      child: Icon(
                        actions[i].icon,
                        size: 18,
                        color: AdminColors.charcoal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            actions[i].title,
                            style: AdminTypography.label.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            actions[i].subtitle,
                            style: AdminTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AdminColors.muted,
                    ),
                  ],
                ),
              ),
            ),
            if (i < actions.length - 1)
              const Divider(height: 10, thickness: 1, color: AdminColors.line),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  AdminBadgeVariant _statusBadgeVariant(String status) =>
      switch (status.toLowerCase()) {
        'delivered' => AdminBadgeVariant.success,
        'dispatched' || 'out for delivery' => AdminBadgeVariant.info,
        'confirmed' => AdminBadgeVariant.neutral,
        'pending' => AdminBadgeVariant.warning,
        'cancelled' => AdminBadgeVariant.error,
        _ => AdminBadgeVariant.neutral,
      };

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  static String _formatCurrency(num amount) {
    return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }
}

// -----------------------------------------------------------------------------
// Sub-components
// -----------------------------------------------------------------------------
class _KpiMetricCard extends StatelessWidget {
  const _KpiMetricCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.isAlert,
    this.isHealthy = false,
    this.isCompact = false,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final bool isAlert;
  final bool isHealthy;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isCompact ? AdminSpacing.lg : AdminSpacing.xl),
      decoration: BoxDecoration(
        color: AdminColors.white,
        border: isAlert
            ? Border.all(color: AdminColors.warningBorder, width: 1.0)
            : AdminBorders.subtle,
        borderRadius: AdminRadii.radiusSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminTypography.tableHeader.copyWith(
                    fontSize: isCompact ? 10 : 11,
                    letterSpacing: isCompact ? 0.8 : 1.2,
                    color: isAlert
                        ? AdminColors.warning
                        : isHealthy
                            ? AdminColors.success
                            : AdminColors.muted,
                  ),
                ),
              ),
              SizedBox(width: isCompact ? 4 : 8),
              Icon(
                icon,
                size: isCompact ? 16 : 18,
                color: isAlert
                    ? AdminColors.warning
                    : isHealthy
                        ? AdminColors.success
                        : AdminColors.muted,
              ),
            ],
          ),
          SizedBox(height: isCompact ? AdminSpacing.sm : AdminSpacing.md),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: isCompact ? 22 : 26,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: AdminColors.charcoal,
            ),
          ),
          SizedBox(height: isCompact ? 2 : AdminSpacing.xs),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AdminTypography.caption.copyWith(
              fontSize: isCompact ? 11 : null,
              height: 1.3,
              color: isAlert
                  ? AdminColors.warning
                  : isHealthy
                      ? AdminColors.success
                      : AdminColors.neutralGrey,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSummaryTile extends StatelessWidget {
  const _MiniSummaryTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AdminTypography.tableHeader.copyWith(fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AdminColors.charcoal,
          ),
        ),
      ],
    );
  }
}

class _StatusBarRow extends StatelessWidget {
  const _StatusBarRow({
    required this.label,
    required this.count,
    required this.total,
    required this.barColor,
  });

  final String label;
  final int count;
  final int total;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final double fraction = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    final int percent = (fraction * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AdminTypography.bodyMedium),
            Text(
              '$count ($percent%)',
              style: AdminTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AdminColors.charcoal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AdminColors.surfaceSubtle,
            borderRadius: AdminRadii.radiusXs,
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: AdminRadii.radiusXs,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricRowItem extends StatelessWidget {
  const _MetricRowItem({
    required this.label,
    required this.value,
    required this.caption,
    this.textColor,
  });

  final String label;
  final String value;
  final String caption;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminTypography.caption),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: textColor ?? AdminColors.charcoal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: AdminTypography.caption.copyWith(
            color: AdminColors.neutralGrey,
          ),
        ),
      ],
    );
  }
}
