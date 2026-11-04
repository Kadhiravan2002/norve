import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../orders/order_providers.dart';
import '../orders/order_repository.dart';
import '../products/product.dart';
import 'widgets/admin_widgets.dart';

/// Redesigned NORVÉ Admin Orders Listing Screen (`/admin/orders`).
///
/// Features an operational, Nexora-inspired order management layout tailored
/// to NORVÉ's luxury editorial design system:
/// - Contextual page header with live order volume and quick refresh.
/// - Operational KPI summary row (Total Orders, Total Items, Awaiting Fulfillment,
///   Delivered, Cancelled).
/// - Horizontally scrollable status navigation tabs with accurate live counts.
/// - Search toolbar (order reference, customer name/email, product items) and payment filter.
/// - Structured administrative data table with currency alignment and status badges.
/// - Contextual row actions for order inspection, status advancement, and COD cash collection.
/// - Responsive pagination and empty states.
class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'all';
  String _selectedPayment = 'all';
  String _searchQuery = '';
  int _currentPage = 1;
  int _pageSize = 10;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedStatus = 'all';
      _selectedPayment = 'all';
      _currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(adminOrdersProvider);

    return Scaffold(
      backgroundColor: AdminColors.ivory,
      body: SafeArea(
        child: ordersAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AdminColors.charcoal,
            ),
          ),
          error: (error, stack) => Center(
            child: AdminEmptyState(
              icon: Icons.error_outline,
              title: 'Orders Unavailable',
              message:
                  'Orders could not be loaded. Please verify database connectivity and administrator permissions.',
              actionLabel: 'Retry Connection',
              onAction: () => ref.invalidate(adminOrdersProvider),
            ),
          ),
          data: (allOrders) => _buildOrdersContent(context, allOrders),
        ),
      ),
    );
  }

  Widget _buildOrdersContent(BuildContext context, List<OrderRecord> allOrders) {
    final hasActiveFilters = _searchQuery.isNotEmpty ||
        _selectedStatus != 'all' ||
        _selectedPayment != 'all';

    // 1. Filter Orders
    final filteredOrders = allOrders.where((order) {
      // Query filter (reference, customer name, email, product item names)
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final referenceMatch = order.reference.toLowerCase().contains(q);
        final customerMatch = order.customerName.toLowerCase().contains(q);
        final emailMatch = order.email.toLowerCase().contains(q);
        final productMatch = order.items.any(
          (item) => item.productName.toLowerCase().contains(q),
        );
        if (!referenceMatch && !customerMatch && !emailMatch && !productMatch) {
          return false;
        }
      }

      // Status filter
      if (_selectedStatus != 'all') {
        if (order.status != _selectedStatus) return false;
      }

      // Payment filter
      if (_selectedPayment != 'all') {
        if (order.paymentStatus != _selectedPayment) return false;
      }

      return true;
    }).toList();

    // 2. Pagination Calculations
    final totalMatching = filteredOrders.length;
    final totalPages = (totalMatching / _pageSize).ceil().clamp(1, 9999);
    final safePage = _currentPage.clamp(1, totalPages);
    final startIndex = (safePage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalMatching);
    final pagedOrders = totalMatching > 0
        ? filteredOrders.sublist(startIndex, endIndex)
        : const <OrderRecord>[];

    return CustomScrollView(
      key: const ValueKey('admin-orders-scroll'),
      slivers: [
        // 1. Page Header
        SliverToBoxAdapter(
          child: AdminPageHeader(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            title: 'Orders',
            subtitle: 'Track and manage customer orders across your boutique.',
            actions: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const BoxDecoration(
                  color: AdminColors.surfaceSubtle,
                  borderRadius: AdminRadii.radiusSm,
                  border: Border.fromBorderSide(AdminBorders.sideSubtle),
                ),
                child: Text(
                  '${allOrders.length} Persisted Orders',
                  style: AdminTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AdminColors.charcoal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AdminButton.secondary(
                key: const ValueKey('refresh-orders-button'),
                size: AdminButtonSize.sm,
                label: 'Refresh',
                icon: const Icon(Icons.refresh, size: 14),
                onPressed: () => ref.invalidate(adminOrdersProvider),
              ),
            ],
          ),
        ),

        // 2. Operational KPI Cards Row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: _buildKpiRow(allOrders),
          ),
        ),

        // 3. Status Tabs Navigation Strip
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
            child: _buildStatusTabs(allOrders),
          ),
        ),

        // 4. Search & Filter Toolbar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
            child: _buildFilterToolbar(
              hasActiveFilters: hasActiveFilters,
              matchingCount: totalMatching,
            ),
          ),
        ),

        // 5. Orders Table & Pagination
        if (allOrders.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: AdminEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No Orders Yet',
                message:
                    'Customer orders will appear here once placed in the boutique storefront.',
              ),
            ),
          )
        else if (filteredOrders.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: AdminEmptyState(
                icon: Icons.search_off_outlined,
                title: 'No Matching Orders',
                message:
                    'No orders match your current search and filter selections.',
                actionLabel: 'Clear All Filters',
                onAction: _clearFilters,
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  _buildOrdersTable(pagedOrders),
                  _buildPaginationBar(
                    totalMatching: totalMatching,
                    startIndex: startIndex + 1,
                    endIndex: endIndex,
                    safePage: safePage,
                    totalPages: totalPages,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // KPI Summary Row (Nexora-Inspired)
  // ---------------------------------------------------------------------------
  Widget _buildKpiRow(List<OrderRecord> allOrders) {
    final totalOrders = allOrders.length;
    final totalItems = allOrders.fold<int>(
      0,
      (sum, order) =>
          sum +
          order.items.fold<int>(0, (itemSum, item) => itemSum + item.quantity),
    );
    final awaitingCount = allOrders
        .where(
          (o) =>
              o.status == 'pending' ||
              o.status == 'confirmed' ||
              o.status == 'processing',
        )
        .length;
    final deliveredCount =
        allOrders.where((o) => o.status == 'delivered').length;
    final cancelledCount =
        allOrders.where((o) => o.status == 'cancelled').length;

    final kpis = [
      (
        label: 'Total Orders',
        value: '$totalOrders',
        caption: 'All boutique requests',
        icon: Icons.receipt_long_outlined,
        badgeVariant: AdminBadgeVariant.neutral,
      ),
      (
        label: 'Items Ordered',
        value: '$totalItems',
        caption: 'Cumulative pieces sold',
        icon: Icons.shopping_bag_outlined,
        badgeVariant: AdminBadgeVariant.neutral,
      ),
      (
        label: 'Awaiting Fulfillment',
        value: '$awaitingCount',
        caption: 'Pending, Confirmed, Processing',
        icon: Icons.pending_actions_outlined,
        badgeVariant: awaitingCount > 0
            ? AdminBadgeVariant.warning
            : AdminBadgeVariant.neutral,
      ),
      (
        label: 'Orders Delivered',
        value: '$deliveredCount',
        caption: 'Completed customer handovers',
        icon: Icons.check_circle_outline,
        badgeVariant: AdminBadgeVariant.success,
      ),
      (
        label: 'Cancelled Orders',
        value: '$cancelledCount',
        caption: 'Terminated or returned',
        icon: Icons.cancel_outlined,
        badgeVariant: cancelledCount > 0
            ? AdminBadgeVariant.error
            : AdminBadgeVariant.neutral,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isCompact = screenWidth < 700;
        final isMobile = screenWidth < 500;

        Widget buildCard(({
          AdminBadgeVariant badgeVariant,
          String caption,
          IconData icon,
          String label,
          String value,
        }) kpi) {
          return _OrderKpiCard(
            label: kpi.label,
            value: kpi.value,
            caption: kpi.caption,
            icon: kpi.icon,
            badgeVariant: kpi.badgeVariant,
            isCompact: isCompact,
            isMobile: isMobile,
          );
        }

        if (screenWidth >= 1050) {
          return Row(
            children: [
              for (int i = 0; i < kpis.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(child: buildCard(kpis[i])),
              ],
            ],
          );
        }

        if (screenWidth >= 700) {
          const cardSpacing = 16.0;
          final itemWidth = (screenWidth - (2 * cardSpacing)) / 3;
          return Wrap(
            spacing: cardSpacing,
            runSpacing: cardSpacing,
            children: [
              for (final kpi in kpis)
                SizedBox(
                  width: itemWidth,
                  child: buildCard(kpi),
                ),
            ],
          );
        }

        // 2-column grid for tablet portrait and all mobile widths (< 700px)
        final spacing = isMobile ? AdminSpacing.md : 12.0;

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
            SizedBox(height: spacing),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: buildCard(kpis[4])),
                  SizedBox(width: spacing),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Status Tabs Navigation Strip (Nexora-Inspired)
  // ---------------------------------------------------------------------------
  Widget _buildStatusTabs(List<OrderRecord> allOrders) {
    int countFor(String status) =>
        allOrders.where((o) => o.status == status).length;

    final tabs = [
      ('all', 'All Orders', allOrders.length),
      ('pending', 'Pending', countFor('pending')),
      ('confirmed', 'Confirmed', countFor('confirmed')),
      ('processing', 'Processing', countFor('processing')),
      ('shipped', 'Shipped', countFor('shipped')),
      ('out_for_delivery', 'Out for Delivery', countFor('out_for_delivery')),
      ('delivered', 'Delivered', countFor('delivered')),
      ('cancelled', 'Cancelled', countFor('cancelled')),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildStatusTabItem(
                keyName: tab.$1,
                label: tab.$2,
                count: tab.$3,
                isSelected: _selectedStatus == tab.$1,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusTabItem({
    required String keyName,
    required String label,
    required int count,
    required bool isSelected,
  }) {
    return InkWell(
      key: ValueKey('order-tab-$keyName'),
      onTap: () {
        if (_selectedStatus != keyName) {
          setState(() {
            _selectedStatus = keyName;
            _currentPage = 1;
          });
        }
      },
      borderRadius: AdminRadii.radiusSm,
      child: AnimatedContainer(
        duration: AdminMotion.duration(context, AdminMotion.hover),
        curve: AdminMotion.curveFast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AdminColors.charcoal : AdminColors.white,
          borderRadius: AdminRadii.radiusSm,
          border: Border.all(
            color: isSelected ? AdminColors.charcoal : AdminColors.lineSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AdminTypography.label.copyWith(
                color: isSelected ? AdminColors.white : AdminColors.charcoal,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AdminColors.white.withValues(alpha: 0.2)
                    : AdminColors.surfaceSubtle,
                borderRadius: AdminRadii.radiusXs,
              ),
              child: Text(
                '$count',
                style: AdminTypography.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AdminColors.white : AdminColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search and Filter Toolbar
  // ---------------------------------------------------------------------------
  Widget _buildFilterToolbar({
    required bool hasActiveFilters,
    required int matchingCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;

        final searchWidget = AdminSearchField(
          key: const ValueKey('admin-orders-search'),
          controller: _searchController,
          hintText: 'Search order reference, customer, email or product…',
          onChanged: (val) => setState(() {
            _searchQuery = val;
            _currentPage = 1;
          }),
          onClear: () => setState(() {
            _searchQuery = '';
            _currentPage = 1;
          }),
        );

        final paymentDropdown = Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: AdminColors.white,
            borderRadius: AdminRadii.radiusSm,
            border: Border.fromBorderSide(AdminBorders.sideSubtle),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const ValueKey('admin-orders-payment-filter'),
              value: _selectedPayment,
              icon: const Icon(
                Icons.arrow_drop_down,
                color: AdminColors.muted,
                size: 20,
              ),
              style: AdminTypography.body,
              dropdownColor: AdminColors.white,
              borderRadius: AdminRadii.radiusSm,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Payments')),
                DropdownMenuItem(
                  value: 'pending',
                  child: Text('Pending COD'),
                ),
                DropdownMenuItem(
                  value: 'collected',
                  child: Text('Cash Collected'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedPayment = val;
                    _currentPage = 1;
                  });
                }
              },
            ),
          ),
        );

        final clearButton = hasActiveFilters
            ? AdminButton.secondary(
                key: const ValueKey('clear-orders-filters-button'),
                size: AdminButtonSize.sm,
                label: 'Clear Filters',
                icon: const Icon(Icons.filter_alt_off_outlined, size: 14),
                onPressed: _clearFilters,
              )
            : null;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchWidget,
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: paymentDropdown),
                  if (clearButton != null) ...[
                    const SizedBox(width: 8),
                    clearButton,
                  ],
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchWidget),
            const SizedBox(width: 12),
            paymentDropdown,
            if (clearButton != null) ...[
              const SizedBox(width: 12),
              clearButton,
            ],
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Orders Data Table (Nexora-Inspired)
  // ---------------------------------------------------------------------------
  Widget _buildOrdersTable(List<OrderRecord> orders) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Minimum width of 860px prevents overflow while fitting comfortably on tablets
        const double minTableWidth = 860;
        final tableWidth = constraints.maxWidth < minTableWidth
            ? minTableWidth
            : constraints.maxWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: AdminTable(
              children: [
                // Table Header Row
                AdminTableHeader(
                  children: const [
                    AdminTableHeaderCell(
                      label: 'Order ID',
                      width: 140,
                    ),
                    AdminTableHeaderCell(
                      label: 'Customer',
                      flex: 3,
                    ),
                    AdminTableHeaderCell(
                      label: 'Date',
                      flex: 2,
                    ),
                    AdminTableHeaderCell(
                      label: 'Items',
                      width: 90,
                    ),
                    AdminTableHeaderCell(
                      label: 'Total',
                      width: 110,
                      alignment: Alignment.centerRight,
                    ),
                    AdminTableHeaderCell(
                      label: 'Payment',
                      width: 135,
                      alignment: Alignment.center,
                    ),
                    AdminTableHeaderCell(
                      label: 'Order Status',
                      width: 135,
                      alignment: Alignment.center,
                    ),
                    AdminTableHeaderCell(
                      label: 'Actions',
                      width: 60,
                      alignment: Alignment.centerRight,
                    ),
                  ],
                ),

                // Order Rows
                for (final order in orders) _buildOrderTableRow(context, order),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderTableRow(BuildContext context, OrderRecord order) {
    final itemCount = order.items.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    return AdminTableRow(
      key: ValueKey('admin-order-${order.id}'),
      onTap: () => context.push('/admin/orders/${order.id}'),
      children: [
        // 1. Order ID
        SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                order.reference,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AdminColors.charcoal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                order.paymentMethod.toUpperCase(),
                style: AdminTypography.caption.copyWith(
                  fontSize: 10,
                  color: AdminColors.muted,
                ),
              ),
            ],
          ),
        ),

        // 2. Customer
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                order.customerName.isEmpty ? 'Guest' : order.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminTypography.bodyBold,
              ),
              const SizedBox(height: 2),
              Text(
                order.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminTypography.caption,
              ),
            ],
          ),
        ),

        // 3. Date
        Expanded(
          flex: 2,
          child: Text(
            _formatDate(order.createdAt),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminTypography.body,
          ),
        ),

        // 4. Items Count
        SizedBox(
          width: 90,
          child: Text(
            '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
            style: AdminTypography.body,
          ),
        ),

        // 5. Total
        SizedBox(
          width: 110,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              formatInr(order.total),
              style: AdminTypography.bodyBold.copyWith(
                color: AdminColors.charcoal,
              ),
            ),
          ),
        ),

        // 6. Payment Badge
        SizedBox(
          width: 135,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _buildPaymentBadge(order.paymentStatus),
            ),
          ),
        ),

        // 7. Order Status Badge
        SizedBox(
          width: 135,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _buildStatusBadge(order.status),
            ),
          ),
        ),

        // 8. Actions Menu
        SizedBox(
          width: 60,
          child: Align(
            alignment: Alignment.centerRight,
            child: _buildRowActionMenu(context, order),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Contextual Row Action Menu
  // ---------------------------------------------------------------------------
  Widget _buildRowActionMenu(BuildContext context, OrderRecord order) {
    final nextStatuses = nextOrderStatuses(order.status);
    final canCollectCod = canCollectCodPayment(order);

    return PopupMenuButton<String>(
      key: ValueKey('order-menu-${order.id}'),
      icon: const Icon(
        Icons.more_vert,
        size: 18,
        color: AdminColors.charcoal,
      ),
      tooltip: 'Order Actions',
      elevation: 3,
      shape: const RoundedRectangleBorder(
        borderRadius: AdminRadii.radiusSm,
        side: AdminBorders.sideSubtle,
      ),
      onSelected: (value) async {
        if (value == 'view') {
          context.push('/admin/orders/${order.id}');
        } else if (value.startsWith('advance:')) {
          final next = value.replaceFirst('advance:', '');
          await _advanceOrderStatus(order, next);
        } else if (value == 'collect_cod') {
          await _collectCod(order);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'view',
          child: Row(
            children: const [
              Icon(Icons.visibility_outlined, size: 16, color: AdminColors.charcoal),
              SizedBox(width: 8),
              Text('View Details', style: AdminTypography.body),
            ],
          ),
        ),
        if (nextStatuses.isNotEmpty) ...[
          const PopupMenuDivider(),
          for (final next in nextStatuses)
            PopupMenuItem(
              value: 'advance:$next',
              child: Row(
                children: [
                  Icon(
                    next == 'cancelled' ? Icons.cancel_outlined : Icons.arrow_forward,
                    size: 16,
                    color: next == 'cancelled'
                        ? AdminColors.error
                        : AdminColors.charcoal,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Mark as ${orderStatusLabel(next)}',
                    style: AdminTypography.body.copyWith(
                      color: next == 'cancelled'
                          ? AdminColors.error
                          : AdminColors.charcoal,
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (canCollectCod) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'collect_cod',
            child: Row(
              children: const [
                Icon(Icons.payments_outlined, size: 16, color: AdminColors.success),
                SizedBox(width: 8),
                Text(
                  'Record COD Collection',
                  style: AdminTypography.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _advanceOrderStatus(OrderRecord order, String nextStatus) async {
    try {
      await ref
          .read(orderRepositoryProvider)
          .updateOrderStatus(order.id, nextStatus);
      ref.invalidate(adminOrdersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order ${order.reference} moved to ${orderStatusLabel(nextStatus)}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update status: $error')),
        );
      }
    }
  }

  Future<void> _collectCod(OrderRecord order) async {
    try {
      await ref.read(orderRepositoryProvider).collectCodPayment(order.id);
      ref.invalidate(adminOrdersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'COD cash collection recorded for order ${order.reference}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record collection: $error')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Status & Payment Badges
  // ---------------------------------------------------------------------------
  Widget _buildPaymentBadge(String paymentStatus) {
    if (paymentStatus == 'collected') {
      return const AdminBadge(
        label: 'Cash Collected',
        variant: AdminBadgeVariant.success,
        showDot: true,
      );
    }
    return const AdminBadge(
      label: 'Pending COD',
      variant: AdminBadgeVariant.warning,
      showDot: true,
    );
  }

  Widget _buildStatusBadge(String status) {
    final label = orderStatusLabel(status);
    return switch (status) {
      'delivered' => AdminBadge(
          label: label,
          variant: AdminBadgeVariant.success,
          showDot: true,
        ),
      'cancelled' => AdminBadge(
          label: label,
          variant: AdminBadgeVariant.error,
          showDot: true,
        ),
      'shipped' || 'out_for_delivery' => AdminBadge(
          label: label,
          variant: AdminBadgeVariant.info,
          showDot: true,
        ),
      _ => AdminBadge(
          label: label,
          variant: AdminBadgeVariant.warning,
          showDot: true,
        ),
    };
  }

  // ---------------------------------------------------------------------------
  // Pagination Bar
  // ---------------------------------------------------------------------------
  Widget _buildPaginationBar({
    required int totalMatching,
    required int startIndex,
    required int endIndex,
    required int safePage,
    required int totalPages,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AdminColors.white,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AdminRadii.sm),
        ),
        border: Border(
          left: AdminBorders.sideSubtle,
          right: AdminBorders.sideSubtle,
          bottom: AdminBorders.sideSubtle,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Range caption
                  Text(
                    'Showing $startIndex–$endIndex of $totalMatching orders',
                    style: AdminTypography.caption,
                  ),

                  const SizedBox(width: 24),

                  // Pagination controls
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Rows per page: ', style: AdminTypography.caption),
                      DropdownButton<int>(
                        value: _pageSize,
                        underline: const SizedBox.shrink(),
                        style: AdminTypography.body,
                        dropdownColor: AdminColors.white,
                        borderRadius: AdminRadii.radiusSm,
                        items: const [
                          DropdownMenuItem(value: 5, child: Text('5')),
                          DropdownMenuItem(value: 10, child: Text('10')),
                          DropdownMenuItem(value: 25, child: Text('25')),
                          DropdownMenuItem(value: 50, child: Text('50')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _pageSize = val;
                              _currentPage = 1;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        key: const ValueKey('pagination-prev'),
                        tooltip: 'Previous page',
                        icon: const Icon(Icons.chevron_left, size: 20),
                        onPressed: safePage > 1
                            ? () => setState(() => _currentPage = safePage - 1)
                            : null,
                      ),
                      Text(
                        '$safePage of $totalPages',
                        style: AdminTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AdminColors.charcoal,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('pagination-next'),
                        tooltip: 'Next page',
                        icon: const Icon(Icons.chevron_right, size: 20),
                        onPressed: safePage < totalPages
                            ? () => setState(() => _currentPage = safePage + 1)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

/// Compact operational metric presentation card for the Orders Listing screen.
class _OrderKpiCard extends StatelessWidget {
  const _OrderKpiCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.badgeVariant,
    this.isCompact = false,
    this.isMobile = false,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final AdminBadgeVariant badgeVariant;
  final bool isCompact;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : (isCompact ? 14 : AdminSpacing.lg),
        vertical: isMobile ? 12 : (isCompact ? 12 : AdminSpacing.lg),
      ),
      decoration: const BoxDecoration(
        color: AdminColors.white,
        border: AdminBorders.subtle,
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
                  style: AdminTypography.tableHeader.copyWith(
                    fontSize: isMobile ? 10 : 11,
                    letterSpacing: isMobile ? 0.8 : 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                size: isMobile ? 16 : 18,
                color: switch (badgeVariant) {
                  AdminBadgeVariant.success => AdminColors.success,
                  AdminBadgeVariant.warning => AdminColors.warning,
                  AdminBadgeVariant.error => AdminColors.error,
                  _ => AdminColors.muted,
                },
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : (isCompact ? AdminSpacing.sm : AdminSpacing.md)),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: isMobile ? 22 : (isCompact ? 22 : 24),
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: AdminColors.charcoal,
            ),
          ),
          SizedBox(height: isMobile ? 2 : AdminSpacing.xs),
          Text(
            caption,
            style: AdminTypography.caption.copyWith(
              fontSize: isMobile ? 11 : null,
              height: 1.25,
              color: AdminColors.neutralGrey,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
