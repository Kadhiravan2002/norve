import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/norve_theme.dart';
import '../orders/order_providers.dart';
import '../orders/order_repository.dart';
import '../products/product.dart';
import '../products/widgets/product_image.dart';
import 'widgets/admin_widgets.dart';

/// Luxury editorial Order Details & Fulfillment screen for the NORVÉ Administration Web platform.
///
/// Features a structured 2-column desktop layout (62% primary / 38% secondary) inspired by Nexora
/// and Wolfpixel design patterns, integrated with NORVÉ's signature editorial typography and
/// restrained color tokens.
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
        loading: () => const Center(
          child: CircularProgressIndicator(color: AdminColors.charcoal),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AdminCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 44,
                    color: AdminColors.error,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Order details could not be loaded. Check administrator access and the database connection.',
                    textAlign: TextAlign.center,
                    style: AdminTypography.body,
                  ),
                  const SizedBox(height: 20),
                  AdminButton.secondary(
                    label: 'Retry',
                    onPressed: () =>
                        ref.invalidate(adminOrderProvider(widget.orderId)),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (order) => CustomScrollView(
          key: const ValueKey('order-details-scroll'),
          slivers: [
            // Page Header with Breadcrumbs and Editorial Reference
            SliverToBoxAdapter(
              child: AdminPageHeader(
                breadcrumbs: InkWell(
                  onTap: _navigateBack,
                  borderRadius: AdminRadii.radiusXs,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.arrow_back,
                          size: 14,
                          color: AdminColors.muted,
                        ),
                        SizedBox(width: 6),
                        Text('Orders', style: AdminTypography.caption),
                      ],
                    ),
                  ),
                ),
                title: order.reference,
                subtitle:
                    '${_date(order.createdAt)} · ${orderStatusLabel(order.status)}',
                actions: [
                  AdminButton.secondary(
                    label: 'Back to Orders',
                    icon: const Icon(Icons.arrow_back, size: 14),
                    onPressed: _navigateBack,
                  ),
                ],
              ),
            ),

            // Two-Column Responsive Content Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 880;

                    if (isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Primary Column (~62%)
                          Expanded(
                            flex: 62,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildItemsCard(order),
                                const SizedBox(height: AdminSpacing.xl),
                                _buildCustomerAndDeliverySection(
                                  order,
                                  isDesktop: true,
                                ),
                                const SizedBox(height: AdminSpacing.xl),
                                _buildProgressionCard(order),
                              ],
                            ),
                          ),
                          const SizedBox(width: AdminSpacing.xl),
                          // Right Action Column (~38%)
                          Expanded(
                            flex: 38,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildFulfillmentActionsCard(order),
                                const SizedBox(height: AdminSpacing.xl),
                                _buildFinancialSummaryCard(order),
                                const SizedBox(height: AdminSpacing.xl),
                                _buildPaymentDetailsCard(order),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    // Mobile & Tablet Stacked Layout (<880px)
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFulfillmentActionsCard(order),
                        const SizedBox(height: AdminSpacing.xl),
                        _buildItemsCard(order),
                        const SizedBox(height: AdminSpacing.xl),
                        _buildFinancialSummaryCard(order),
                        const SizedBox(height: AdminSpacing.xl),
                        _buildPaymentDetailsCard(order),
                        const SizedBox(height: AdminSpacing.xl),
                        _buildCustomerAndDeliverySection(
                          order,
                          isDesktop: false,
                        ),
                        const SizedBox(height: AdminSpacing.xl),
                        _buildProgressionCard(order),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/admin/orders');
    }
  }

  // ---------------------------------------------------------------------------
  // Left Column: Order Items
  // ---------------------------------------------------------------------------
  Widget _buildItemsCard(OrderRecord order) {
    final count = order.items.length;
    return AdminCard(
      title: 'Items',
      subtitle: '$count ${count == 1 ? 'item' : 'items'} in this order',
      padding: EdgeInsets.zero,
      child: order.items.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(AdminSpacing.xl),
              child: Text(
                'No items recorded for this order.',
                style: AdminTypography.caption,
              ),
            )
          : Column(
              children: [
                for (int i = 0; i < order.items.length; i++) ...[
                  if (i > 0) const AdminDivider(),
                  _buildOrderItemRow(order.items[i]),
                ],
              ],
            ),
    );
  }

  Widget _buildOrderItemRow(OrderItemSnapshot item) {
    final variantInfo = productVariantLabel(item.size, item.color);
    return Padding(
      padding: const EdgeInsets.all(AdminSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Product Thumbnail
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: AdminColors.surfaceSubtle,
              border: AdminBorders.subtle,
              borderRadius: AdminRadii.radiusSm,
            ),
            clipBehavior: Clip.antiAlias,
            child: item.imageUrl.trim().isNotEmpty
                ? ProductImage(url: item.imageUrl, fit: BoxFit.cover)
                : const Center(
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: 22,
                      color: AdminColors.neutralGrey,
                    ),
                  ),
          ),
          const SizedBox(width: AdminSpacing.lg),
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: AdminTypography.bodyBold,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  variantInfo.isEmpty ? 'Single option' : variantInfo,
                  style: AdminTypography.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatInr(item.unitPrice)} each',
                  style: AdminTypography.caption.copyWith(
                    color: AdminColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          // Quantity Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: const BoxDecoration(
              color: AdminColors.surfaceSubtle,
              border: AdminBorders.subtle,
              borderRadius: AdminRadii.radiusSm,
            ),
            child: Text(
              'Qty: ${item.quantity}',
              style: AdminTypography.label,
            ),
          ),
          const SizedBox(width: AdminSpacing.xl),
          // Line Total
          SizedBox(
            width: 85,
            child: Text(
              formatInr(item.lineTotal),
              textAlign: TextAlign.right,
              style: AdminTypography.bodyBold.copyWith(
                fontSize: 14,
                color: AdminColors.charcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Left Column: Customer & Delivery Information
  // ---------------------------------------------------------------------------
  Widget _buildCustomerAndDeliverySection(
    OrderRecord order, {
    required bool isDesktop,
  }) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildCustomerCard(order)),
          const SizedBox(width: AdminSpacing.xl),
          Expanded(child: _buildDeliveryAddressCard(order)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCustomerCard(order),
        const SizedBox(height: AdminSpacing.xl),
        _buildDeliveryAddressCard(order),
      ],
    );
  }

  Widget _buildCustomerCard(OrderRecord order) {
    return AdminCard(
      title: 'Customer',
      subtitle: 'Contact details and profile info.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AdminColors.surfaceSubtle,
                  shape: BoxShape.circle,
                  border: AdminBorders.subtle,
                ),
                child: Center(
                  child: Text(
                    order.customerName.isNotEmpty
                        ? order.customerName[0].toUpperCase()
                        : 'C',
                    style: AdminTypography.bodyBold,
                  ),
                ),
              ),
              const SizedBox(width: AdminSpacing.md),
              Expanded(
                child: Text(
                  order.customerName.isEmpty
                      ? 'Guest Customer'
                      : order.customerName,
                  style: AdminTypography.bodyBold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.lg),
          const AdminDivider(),
          const SizedBox(height: AdminSpacing.md),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: order.email.isEmpty ? 'Not provided' : order.email,
          ),
          const SizedBox(height: AdminSpacing.sm),
          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: order.phone.isEmpty ? 'Not provided' : order.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddressCard(OrderRecord order) {
    final streetLine = order.streetArea.isEmpty
        ? order.addressLine2
        : order.streetArea;
    final fullAddress = [
      order.addressLine1,
      if (streetLine.isNotEmpty) streetLine,
      if (order.landmark.isNotEmpty) 'Landmark: ${order.landmark}',
      '${order.city}, ${order.region} ${order.postalCode}',
      order.country,
    ].join('\n');

    return AdminCard(
      title: 'Delivery address',
      action: AdminBadge(
        label: order.addressLabel.isEmpty ? 'Delivery' : order.addressLabel,
        variant: AdminBadgeVariant.neutral,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: AdminColors.muted,
              ),
              const SizedBox(width: AdminSpacing.sm),
              Expanded(
                child: Text(
                  fullAddress,
                  style: AdminTypography.body.copyWith(height: 1.55),
                ),
              ),
            ],
          ),
          if (order.phone.isNotEmpty) ...[
            const SizedBox(height: AdminSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 14,
                  color: AdminColors.muted,
                ),
                const SizedBox(width: AdminSpacing.sm),
                Text(
                  'Contact: ${order.phone}',
                  style: AdminTypography.caption,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AdminColors.muted),
        const SizedBox(width: AdminSpacing.sm),
        Text(
          '$label: ',
          style: AdminTypography.caption.copyWith(fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: AdminTypography.body,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Left Column: Progression Timeline
  // ---------------------------------------------------------------------------
  Widget _buildProgressionCard(OrderRecord order) {
    final isCancelled = order.status == 'cancelled';
    const steps = [
      (
        key: 'pending',
        title: 'Order Placed',
        subtitle: 'Customer placed order via online checkout',
      ),
      (
        key: 'confirmed',
        title: 'Order Confirmed',
        subtitle: 'Order confirmed and inventory allocated',
      ),
      (
        key: 'processing',
        title: 'In Processing',
        subtitle: 'Boutique packing and preparation in progress',
      ),
      (
        key: 'shipped',
        title: 'Dispatched',
        subtitle: 'Package handed over to delivery courier',
      ),
      (
        key: 'out_for_delivery',
        title: 'Out for Delivery',
        subtitle: 'Courier out for doorstep delivery',
      ),
      (
        key: 'delivered',
        title: 'Delivered',
        subtitle: 'Package successfully delivered to recipient',
      ),
    ];
    final currentIdx = steps.indexWhere((s) => s.key == order.status);

    return AdminCard(
      title: 'Order Progression',
      subtitle: isCancelled
          ? 'This order has been cancelled and its inventory released.'
          : 'Fulfillment milestone tracking along the delivery lifecycle.',
      child: isCancelled
          ? Container(
              padding: const EdgeInsets.all(AdminSpacing.lg),
              decoration: BoxDecoration(
                color: AdminColors.errorBg,
                border: Border.all(color: AdminColors.errorBorder),
                borderRadius: AdminRadii.radiusSm,
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.cancel_outlined,
                    color: AdminColors.error,
                    size: 20,
                  ),
                  SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: Text(
                      'Order was cancelled. No further fulfillment actions can be performed.',
                      style: AdminTypography.body,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (int i = 0; i < steps.length; i++)
                  _buildTimelineStep(
                    title: steps[i].title,
                    subtitle: steps[i].subtitle,
                    isCompleted: i < currentIdx,
                    isCurrent: i == currentIdx,
                    isLast: i == steps.length - 1,
                  ),
              ],
            ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Indicator & Connector
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? AdminColors.charcoal
                        : (isCurrent
                            ? AdminColors.charcoal
                            : AdminColors.white),
                    border: Border.all(
                      color: isCompleted || isCurrent
                          ? AdminColors.charcoal
                          : AdminColors.line,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                            Icons.check,
                            size: 12,
                            color: AdminColors.white,
                          )
                        : (isCurrent
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AdminColors.white,
                                ),
                              )
                            : null),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: isCompleted
                          ? AdminColors.charcoal
                          : AdminColors.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          // Step Label & Description
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AdminSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AdminTypography.bodyBold.copyWith(
                      color: isCompleted || isCurrent
                          ? AdminColors.charcoal
                          : AdminColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: AdminTypography.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Right Column: Order Fulfillment Actions
  // ---------------------------------------------------------------------------
  Widget _buildFulfillmentActionsCard(OrderRecord order) {
    final nextList = _nextStatuses(order.status);
    final canCollectCod = canCollectCodPayment(order);

    return AdminCard(
      title: 'Update order status',
      action: _buildStatusBadge(order.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(AdminSpacing.md),
              decoration: BoxDecoration(
                color: AdminColors.errorBg,
                border: Border.all(color: AdminColors.errorBorder),
                borderRadius: AdminRadii.radiusSm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AdminColors.error,
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    child: Text(
                      _error!,
                      key: const ValueKey('admin-order-error'),
                      style: AdminTypography.caption.copyWith(
                        color: AdminColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AdminSpacing.md),
          ],

          // Lifecycle Advance Buttons
          if (nextList.isNotEmpty) ...[
            Text(
              'Advance Lifecycle Stage',
              style: AdminTypography.label,
            ),
            const SizedBox(height: AdminSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in nextList) ...[
                  if (status == 'cancelled')
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminColors.error,
                        side: const BorderSide(color: AdminColors.errorBorder),
                      ),
                      onPressed: _saving ? null : () => _updateStatus(status),
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AdminColors.error,
                              ),
                            )
                          : Text(orderStatusLabel(status)),
                    )
                  else
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminColors.charcoal,
                        side: const BorderSide(color: AdminColors.charcoal),
                      ),
                      onPressed: _saving ? null : () => _updateStatus(status),
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AdminColors.charcoal,
                              ),
                            )
                          : Text(orderStatusLabel(status)),
                    ),
                ],
              ],
            ),
          ] else ...[
            Text(
              'This order is in a final status.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NorveColors.muted,
                  ),
            ),
          ],

          // COD Payment Collection Action
          if (canCollectCod) ...[
            const SizedBox(height: AdminSpacing.lg),
            const AdminDivider(),
            const SizedBox(height: AdminSpacing.lg),
            Text(
              'Payment Collection',
              style: AdminTypography.label,
            ),
            const SizedBox(height: 4),
            Text(
              'Order delivered. Record cash receipt of ${formatInr(order.total)} to complete reconciliation.',
              style: AdminTypography.caption,
            ),
            const SizedBox(height: AdminSpacing.md),
            FilledButton.icon(
              key: const ValueKey('collect-cod-payment'),
              style: FilledButton.styleFrom(
                backgroundColor: AdminColors.charcoal,
                foregroundColor: AdminColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saving ? null : _confirmCollection,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AdminColors.white,
                      ),
                    )
                  : const Icon(Icons.payments_outlined, size: 18),
              label: const Text('Mark cash collected'),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Right Column: Financial Summary
  // ---------------------------------------------------------------------------
  Widget _buildFinancialSummaryCard(OrderRecord order) {
    return AdminCard(
      title: 'Financial Summary',
      subtitle: 'Order subtotal, shipping, and tax calculations.',
      child: Column(
        children: [
          _total('Items subtotal', order.subtotal),
          _total('Delivery', order.shipping),
          _total('Tax', order.tax),
          const SizedBox(height: AdminSpacing.xs),
          const AdminDivider(),
          const SizedBox(height: AdminSpacing.xs),
          _total('Order total', order.total, strong: true),
        ],
      ),
    );
  }

  Widget _total(String label, int amount, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AdminTypography.body.copyWith(
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
                  fontSize: strong ? 14 : 13,
                  color: AdminColors.charcoal,
                ),
              ),
            ),
            Text(
              formatInr(amount),
              style: AdminTypography.body.copyWith(
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                fontSize: strong ? 15 : 13,
                color: AdminColors.charcoal,
              ),
            ),
          ],
        ),
      );

  // ---------------------------------------------------------------------------
  // Right Column: Payment Details
  // ---------------------------------------------------------------------------
  Widget _buildPaymentDetailsCard(OrderRecord order) {
    final isCollected = order.paymentStatus == 'collected';

    return AdminCard(
      title: 'Payment Details',
      action: _buildPaymentBadge(order.paymentStatus),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPaymentRow('Payment method', 'Cash on Delivery'),
          const SizedBox(height: AdminSpacing.sm),
          _buildPaymentRow(
            'Payment status',
            paymentStatusLabel(order.paymentStatus),
          ),
          const SizedBox(height: AdminSpacing.sm),
          _buildPaymentRow(
            'Amount Collected',
            isCollected ? formatInr(order.total) : '₹0',
          ),
          const SizedBox(height: AdminSpacing.sm),
          _buildPaymentRow(
            'Pending Balance',
            isCollected ? '₹0' : formatInr(order.total),
          ),
          const SizedBox(height: AdminSpacing.md),
          Container(
            padding: const EdgeInsets.all(AdminSpacing.md),
            decoration: const BoxDecoration(
              color: AdminColors.surfaceSubtle,
              border: AdminBorders.subtle,
              borderRadius: AdminRadii.radiusSm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AdminColors.muted,
                ),
                const SizedBox(width: AdminSpacing.sm),
                Expanded(
                  child: Text(
                    isCollected
                        ? 'Cash payment has been confirmed and settled into company records.'
                        : 'Cash must be collected at customer doorstep before finalizing delivery reconciliation.',
                    style: AdminTypography.caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AdminTypography.body,
          ),
        ),
        const SizedBox(width: AdminSpacing.sm),
        Text(
          value,
          style: AdminTypography.bodyMedium,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Badges
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
  // Status and Payment Operations
  // ---------------------------------------------------------------------------
  List<String> _nextStatuses(String status) => nextOrderStatuses(status);

  Future<void> _confirmCollection() async {
    final confirmed = await AdminConfirmationDialog.show(
      context,
      title: 'Confirm cash collection',
      message: 'Confirm that cash was received for this order.',
      confirmLabel: 'Confirm collection',
      cancelLabel: 'Cancel',
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
      final confirmed = await AdminConfirmationDialog.show(
        context,
        title: 'Cancel this order?',
        message:
            'This will cancel the order and restore eligible reserved stock.',
        confirmLabel: 'Confirm cancellation',
        cancelLabel: 'Keep order',
        isDestructive: true,
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

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
