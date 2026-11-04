import 'package:flutter/material.dart';

import '../../../core/theme/norve_admin_tokens.dart';
import '../../products/product.dart';
import '../../products/widgets/product_image.dart';
import '../admin_metrics.dart';
import 'admin_badges.dart';

/// Luxury product card for the NORVÉ administration platform.
///
/// Combines the product card grid layout and color swatch details from the
/// primary NETIC reference with the clean architectural spacing, restrained
/// borders, and editorial typography of the secondary Wolfpixel reference.
class AdminProductCard extends StatefulWidget {
  const AdminProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<AdminProductCard> createState() => _AdminProductCardState();
}

class _AdminProductCardState extends State<AdminProductCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isLowStock =
        product.stockQuantity <= lowStockThreshold && product.stockQuantity > 0;
    final isOutOfStock = product.stockQuantity == 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AdminMotion.duration(context, AdminMotion.hover),
          curve: AdminMotion.curveFast,
          decoration: BoxDecoration(
            color: AdminColors.white,
            border: Border.all(
              color: _isHovered ? AdminColors.charcoal : AdminColors.line,
              width: 1.0,
            ),
            borderRadius: AdminRadii.radiusSm,
            boxShadow: _isHovered
                ? const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(AdminSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Header: Product Name, Category and Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: AdminColors.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.category.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AdminTypography.tableHeader.copyWith(
                            fontSize: 10,
                            letterSpacing: 0.8,
                            color: AdminColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  AdminBadge(
                    label: product.isActive ? 'Active' : 'Draft',
                    variant: product.isActive
                        ? AdminBadgeVariant.success
                        : AdminBadgeVariant.neutral,
                    showDot: true,
                  ),
                ],
              ),
              const SizedBox(height: AdminSpacing.md),

              // 2. Center: Product Image Container with NETIC Color Swatches
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AdminColors.surfaceSubtle,
                    borderRadius: AdminRadii.radiusXs,
                    border: Border.fromBorderSide(AdminBorders.sideSubtle),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Centered product image
                      Padding(
                        padding: const EdgeInsets.all(AdminSpacing.md),
                        child: Center(
                          child: ProductImage(
                            url: product.imageUrl,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      // Low stock or sold out indicator
                      if (isLowStock)
                        const Positioned(
                          top: 8,
                          left: 8,
                          child: AdminBadge(
                            label: 'Low stock',
                            variant: AdminBadgeVariant.warning,
                            showDot: true,
                          ),
                        )
                      else if (isOutOfStock)
                        const Positioned(
                          top: 8,
                          left: 8,
                          child: AdminBadge(
                            label: 'Sold out',
                            variant: AdminBadgeVariant.error,
                            showDot: false,
                          ),
                        ),

                      // NETIC reference element: Vertical color variant indicator dots
                      if (product.colors.isNotEmpty)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final color in product.colors.take(4))
                                Container(
                                  margin: const EdgeInsets.only(bottom: 5),
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    color: Color(color.value | 0xFF000000),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AdminColors.line,
                                      width: 1,
                                    ),
                                  ),
                                ),
                              if (product.colors.length > 4)
                                Text(
                                  '+${product.colors.length - 4}',
                                  style: AdminTypography.caption.copyWith(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: AdminColors.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AdminSpacing.md),

              // 3. Metadata: SKU and Stock level
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      product.sku.isNotEmpty ? 'SKU: ${product.sku}' : 'SKU: —',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminTypography.caption.copyWith(
                        color: AdminColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  Text(
                    '${product.stockQuantity} in stock',
                    style: AdminTypography.caption.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isLowStock
                          ? AdminColors.warning
                          : isOutOfStock
                              ? AdminColors.error
                              : AdminColors.charcoal,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AdminSpacing.sm),
              const Divider(height: 1, thickness: 1, color: AdminColors.line),
              const SizedBox(height: AdminSpacing.sm),

              // 4. Footer: Price Display and Management Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Price block (original strikethrough price when present + selling price)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (product.originalPrice != null &&
                          product.originalPrice! > product.price)
                        Text(
                          formatInr(product.originalPrice!),
                          style: AdminTypography.caption.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: AdminColors.neutralGrey,
                            fontSize: 11,
                            height: 1.1,
                          ),
                        ),
                      Text(
                        product.formattedPrice,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          color: AdminColors.charcoal,
                        ),
                      ),
                    ],
                  ),

                  // Actions: Edit and Delete icon buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: ValueKey('admin-edit-product-${product.id}'),
                        tooltip: 'Edit ${product.name}',
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AdminColors.charcoal,
                        ),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        splashRadius: 18,
                        onPressed: widget.onEdit,
                      ),
                      const SizedBox(width: AdminSpacing.xxs),
                      IconButton(
                        key: ValueKey('admin-delete-product-${product.id}'),
                        tooltip: 'Delete ${product.name}',
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AdminColors.error,
                        ),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        splashRadius: 18,
                        onPressed: widget.onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
