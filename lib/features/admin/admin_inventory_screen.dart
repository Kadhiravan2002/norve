import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/supabase_providers.dart';
import '../products/product.dart';
import '../products/product_catalog_provider.dart';
import '../products/product_repository.dart';
import '../products/widgets/catalog_state_notice.dart';
import '../products/widgets/product_image.dart';
import 'admin_metrics.dart';
import 'widgets/admin_widgets.dart';

/// Luxury editorial Inventory Management screen for the NORVÉ Administration platform.
///
/// Features high-density SaaS variant stock control, atomic stock updates,
/// real-time KPI metrics, responsive filtering, and expandable variant tables.
class AdminInventoryScreen extends ConsumerStatefulWidget {
  const AdminInventoryScreen({super.key});

  @override
  ConsumerState<AdminInventoryScreen> createState() =>
      _AdminInventoryScreenState();
}

class _AdminInventoryScreenState extends ConsumerState<AdminInventoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _category = 'All categories';
  String _stockFilter = 'all';
  String _sortBy = 'name_asc';
  final Set<String> _expandedProductIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleExpanded(String productId) {
    setState(() {
      if (_expandedProductIds.contains(productId)) {
        _expandedProductIds.remove(productId);
      } else {
        _expandedProductIds.add(productId);
      }
    });
  }

  void _toggleExpandAll(List<Product> products) {
    setState(() {
      if (_expandedProductIds.length == products.length) {
        _expandedProductIds.clear();
      } else {
        _expandedProductIds.addAll(products.map((p) => p.id));
      }
    });
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _query = '';
      _category = 'All categories';
      _stockFilter = 'all';
      _sortBy = 'name_asc';
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(productCatalogProvider);
    final status = ref.watch(catalogLoadStateProvider);
    final categories =
        ref.watch(productCategoriesProvider).asData?.value ??
        const <ProductCategory>[];
    final available =
        status.phase == CatalogPhase.live ||
        status.phase == CatalogPhase.development;

    // Filter products
    final filtered = catalog.where((product) {
      final matchesQuery = '${product.name} ${product.sku}'
          .toLowerCase()
          .contains(_query.toLowerCase().trim());
      final matchesCategory =
          _category == 'All categories' || product.category == _category;

      bool matchesStock = true;
      if (_stockFilter == 'in_stock') {
        matchesStock = product.stockQuantity > lowStockThreshold;
      } else if (_stockFilter == 'low_stock') {
        matchesStock = product.stockQuantity > 0 &&
            product.stockQuantity <= lowStockThreshold;
      } else if (_stockFilter == 'out_of_stock') {
        matchesStock = product.stockQuantity == 0;
      }

      return matchesQuery && matchesCategory && matchesStock;
    }).toList();

    // Sort products
    switch (_sortBy) {
      case 'name_desc':
        filtered.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
      case 'stock_asc':
        filtered.sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));
        break;
      case 'stock_desc':
        filtered.sort((a, b) => b.stockQuantity.compareTo(a.stockQuantity));
        break;
      case 'sku_asc':
        filtered.sort(
          (a, b) => a.sku.toLowerCase().compareTo(b.sku.toLowerCase()),
        );
        break;
      case 'name_asc':
      default:
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
    }

    // KPI Summary Calculations
    final totalProducts = catalog.length;
    final totalStockUnits = catalog.fold<int>(
      0,
      (sum, p) => sum + p.stockQuantity,
    );
    final lowStockCount = catalog.fold<int>(
      0,
      (sum, p) =>
          sum +
          (p.variants.isNotEmpty
              ? p.variants
                  .where(
                    (v) =>
                        v.stockQuantity > 0 &&
                        v.stockQuantity <= lowStockThreshold,
                  )
                  .length
              : (p.stockQuantity > 0 && p.stockQuantity <= lowStockThreshold
                  ? 1
                  : 0)),
    );
    final outOfStockCount = catalog.fold<int>(
      0,
      (sum, p) =>
          sum +
          (p.variants.isNotEmpty
              ? p.variants.where((v) => v.stockQuantity == 0).length
              : (p.stockQuantity == 0 ? 1 : 0)),
    );

    return Scaffold(
      backgroundColor: AdminColors.surfaceSubtle,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final isCompact = maxWidth < 960;

            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: CatalogStateNotice()),

                // Page Header
                SliverToBoxAdapter(
                  child: AdminPageHeader(
                    title: 'Inventory',
                    subtitle:
                        'Stock is updated per variant. Order placement continues to deduct stock atomically.',
                    actions: [
                      AdminButton.secondary(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: 'Refresh catalogue',
                        onPressed: () =>
                            ref.read(productCatalogProvider.notifier).refresh(),
                      ),
                    ],
                  ),
                ),

                // KPI Overview Row
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: _buildKpiRow(
                      maxWidth,
                      totalProducts: totalProducts,
                      totalStockUnits: totalStockUnits,
                      lowStockCount: lowStockCount,
                      outOfStockCount: outOfStockCount,
                    ),
                  ),
                ),

                // Search, Filter & Action Toolbar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: _buildFilterBar(
                      isCompact: isCompact,
                      categories: categories,
                      filteredProducts: filtered,
                    ),
                  ),
                ),

                // Catalogue Empty State
                if (available && catalog.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 40,
                            color: AdminColors.neutralGrey,
                          ),
                          const SizedBox(height: AdminSpacing.md),
                          Text(
                            'No products in the catalogue.',
                            style: AdminTypography.sectionTitle,
                          ),
                          const SizedBox(height: AdminSpacing.xs),
                          const Text(
                            'Add products to your catalogue to begin managing inventory.',
                            style: AdminTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  )
                // Filter No Results State
                else if (available && filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.search_off_outlined,
                            size: 40,
                            color: AdminColors.neutralGrey,
                          ),
                          const SizedBox(height: AdminSpacing.md),
                          Text(
                            'No products match these filters.',
                            style: AdminTypography.sectionTitle,
                          ),
                          const SizedBox(height: AdminSpacing.xs),
                          const Text(
                            'Try adjusting your search query, category, or stock level filters.',
                            style: AdminTypography.caption,
                          ),
                          const SizedBox(height: AdminSpacing.lg),
                          AdminButton.secondary(
                            label: 'Clear filters',
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: _resetFilters,
                          ),
                        ],
                      ),
                    ),
                  )
                // Inventory Listing Table
                else if (available)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                      child: _buildInventoryTable(
                        isCompact: isCompact,
                        products: filtered,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KPI Summary Row
  // ---------------------------------------------------------------------------
  Widget _buildKpiRow(
    double maxWidth, {
    required int totalProducts,
    required int totalStockUnits,
    required int lowStockCount,
    required int outOfStockCount,
  }) {
    final kpis = [
      (
        label: 'Total Products',
        value: '$totalProducts',
        caption: 'Boutique styles tracked',
        icon: Icons.inventory_2_outlined,
      ),
      (
        label: 'Total Stock Units',
        value: '$totalStockUnits',
        caption: 'Available across all variants',
        icon: Icons.layers_outlined,
      ),
      (
        label: 'Low Stock Variants',
        value: '$lowStockCount',
        caption: 'Threshold: ≤ $lowStockThreshold units',
        icon: Icons.warning_amber_outlined,
      ),
      (
        label: 'Out of Stock',
        value: '$outOfStockCount',
        caption: 'Requires immediate replenishment',
        icon: Icons.error_outline,
      ),
    ];

    if (maxWidth < 960) {
      // 2x2 grid on compact screens
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildKpiCard(kpis[0])),
              const SizedBox(width: AdminSpacing.md),
              Expanded(child: _buildKpiCard(kpis[1])),
            ],
          ),
          const SizedBox(height: AdminSpacing.md),
          Row(
            children: [
              Expanded(child: _buildKpiCard(kpis[2])),
              const SizedBox(width: AdminSpacing.md),
              Expanded(child: _buildKpiCard(kpis[3])),
            ],
          ),
        ],
      );
    }

    // 4 columns on desktop
    return Row(
      children: [
        for (int i = 0; i < kpis.length; i++) ...[
          if (i > 0) const SizedBox(width: AdminSpacing.md),
          Expanded(child: _buildKpiCard(kpis[i])),
        ],
      ],
    );
  }

  Widget _buildKpiCard(({
    String caption,
    IconData icon,
    String label,
    String value,
  }) kpi) {
    return AdminCard(
      padding: const EdgeInsets.all(AdminSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  kpi.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminTypography.tableHeader.copyWith(
                    color: AdminColors.muted,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: AdminSpacing.xs),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AdminColors.surfaceSubtle,
                  borderRadius: AdminRadii.radiusSm,
                  border: AdminBorders.subtle,
                ),
                child: Icon(kpi.icon, size: 16, color: AdminColors.charcoal),
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.sm),
          Text(
            kpi.value,
            style: AdminTypography.pageTitle.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            kpi.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminTypography.caption.copyWith(
              color: AdminColors.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search, Filter & Action Toolbar
  // ---------------------------------------------------------------------------
  Widget _buildFilterBar({
    required bool isCompact,
    required List<ProductCategory> categories,
    required List<Product> filteredProducts,
  }) {
    final searchField = Container(
      height: 40,
      decoration: const BoxDecoration(
        color: AdminColors.white,
        border: AdminBorders.subtle,
        borderRadius: AdminRadii.radiusSm,
      ),
      child: TextField(
        key: const ValueKey('inventory-search'),
        controller: _searchController,
        cursorColor: AdminColors.charcoal,
        style: AdminTypography.body,
        onChanged: (val) => setState(() => _query = val),
        decoration: InputDecoration(
          hintText: 'Search product or SKU',
          hintStyle: AdminTypography.caption.copyWith(fontSize: 13),
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: AdminColors.muted,
          ),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: AdminColors.muted,
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          isDense: true,
        ),
      ),
    );

    final categoryDropdown = SizedBox(
      width: isCompact ? null : 180,
      height: 40,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.md),
        decoration: const BoxDecoration(
          color: AdminColors.white,
          border: AdminBorders.subtle,
          borderRadius: AdminRadii.radiusSm,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            key: ValueKey('inventory-category-$_category'),
            value: _category,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: AdminColors.muted,
            ),
            style: AdminTypography.body,
            onChanged: (val) =>
                setState(() => _category = val ?? 'All categories'),
            items: [
              'All categories',
              ...categories.map((c) => c.name),
            ].map((cat) {
              return DropdownMenuItem(
                value: cat,
                child: Text(
                  cat,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminTypography.body.copyWith(
                    fontWeight:
                        cat == _category ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );

    final stockFilterDropdown = SizedBox(
      width: isCompact ? null : 180,
      height: 40,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.md),
        decoration: const BoxDecoration(
          color: AdminColors.white,
          border: AdminBorders.subtle,
          borderRadius: AdminRadii.radiusSm,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            key: ValueKey('inventory-stock-filter-$_stockFilter'),
            value: _stockFilter,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: AdminColors.muted,
            ),
            style: AdminTypography.body,
            onChanged: (val) => setState(() => _stockFilter = val ?? 'all'),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text(
                  'All stock levels',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'in_stock',
                child: Text(
                  'In stock',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'low_stock',
                child: Text(
                  'Low stock (≤ 5)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'out_of_stock',
                child: Text(
                  'Out of stock (0)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final sortDropdown = SizedBox(
      width: isCompact ? null : 170,
      height: 40,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.md),
        decoration: const BoxDecoration(
          color: AdminColors.white,
          border: AdminBorders.subtle,
          borderRadius: AdminRadii.radiusSm,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            key: ValueKey('inventory-sort-$_sortBy'),
            value: _sortBy,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: AdminColors.muted,
            ),
            style: AdminTypography.body,
            onChanged: (val) => setState(() => _sortBy = val ?? 'name_asc'),
            items: const [
              DropdownMenuItem(
                value: 'name_asc',
                child: Text(
                  'Sort by Name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'stock_asc',
                child: Text(
                  'Lowest Stock First',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'stock_desc',
                child: Text(
                  'Highest Stock First',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'sku_asc',
                child: Text(
                  'Sort by SKU',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final isAllExpanded =
        filteredProducts.isNotEmpty &&
        _expandedProductIds.length == filteredProducts.length;

    final expandAllButton = Container(
      height: 40,
      decoration: const BoxDecoration(
        color: AdminColors.white,
        border: AdminBorders.subtle,
        borderRadius: AdminRadii.radiusSm,
      ),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.md),
          foregroundColor: AdminColors.charcoal,
        ),
        icon: Icon(
          isAllExpanded ? Icons.unfold_less : Icons.unfold_more,
          size: 16,
          color: AdminColors.muted,
        ),
        label: Text(
          isAllExpanded ? 'Collapse all' : 'Expand all',
          style: AdminTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: AdminColors.charcoal,
          ),
        ),
        onPressed: filteredProducts.isEmpty
            ? null
            : () => _toggleExpandAll(filteredProducts),
      ),
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchField,
          const SizedBox(height: AdminSpacing.sm),
          Row(
            children: [
              Expanded(child: categoryDropdown),
              const SizedBox(width: AdminSpacing.sm),
              Expanded(child: stockFilterDropdown),
            ],
          ),
          const SizedBox(height: AdminSpacing.sm),
          Row(
            children: [
              Expanded(child: sortDropdown),
              const SizedBox(width: AdminSpacing.sm),
              expandAllButton,
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: searchField),
        const SizedBox(width: AdminSpacing.md),
        categoryDropdown,
        const SizedBox(width: AdminSpacing.md),
        stockFilterDropdown,
        const SizedBox(width: AdminSpacing.md),
        sortDropdown,
        const SizedBox(width: AdminSpacing.md),
        expandAllButton,
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Main Inventory Table
  // ---------------------------------------------------------------------------
  Widget _buildInventoryTable({
    required bool isCompact,
    required List<Product> products,
  }) {
    return AdminTable(
      children: [
        // Table Header
        if (!isCompact)
          const AdminTableHeader(
            children: [
              SizedBox(width: 44), // Chevron indent
              AdminTableHeaderCell(label: 'Product & SKU', flex: 3),
              AdminTableHeaderCell(label: 'Category', width: 140),
              AdminTableHeaderCell(label: 'Status', width: 100),
              AdminTableHeaderCell(label: 'Total Stock', width: 120),
              AdminTableHeaderCell(label: 'Stock Health', width: 130),
              AdminTableHeaderCell(label: 'Variants', width: 110),
            ],
          ),

        // Product Rows
        for (final product in products)
          _ProductInventoryItem(
            product: product,
            isCompact: isCompact,
            isExpanded: _expandedProductIds.contains(product.id),
            onToggle: () => _toggleExpanded(product.id),
          ),
      ],
    );
  }
}

// =============================================================================
// Product Inventory Item (Expandable Row + Nested Variant Workspace)
// =============================================================================
class _ProductInventoryItem extends StatelessWidget {
  const _ProductInventoryItem({
    required this.product,
    required this.isCompact,
    required this.isExpanded,
    required this.onToggle,
  });

  final Product product;
  final bool isCompact;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.stockQuantity == 0;
    final lowStock =
        product.stockQuantity > 0 && product.stockQuantity <= lowStockThreshold;

    final hasImage =
        product.imageUrl.isNotEmpty && product.imageUrl.startsWith('http');

    return Container(
      key: ValueKey('inventory-${product.id}'),
      decoration: BoxDecoration(
        color: isExpanded ? AdminColors.surfaceSubtle : AdminColors.white,
        border: const Border(
          bottom: AdminBorders.sideSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Parent Product Row
          InkWell(
            onTap: onToggle,
            hoverColor: AdminColors.surfaceSubtle.withAlpha(160),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AdminSpacing.lg,
                vertical: AdminSpacing.md,
              ),
              child: isCompact
                  ? _buildCompactProductRow(context, outOfStock, lowStock, hasImage)
                  : _buildDesktopProductRow(context, outOfStock, lowStock, hasImage),
            ),
          ),

          // Expanded Variant Inventory Workspace
          AnimatedSize(
            duration: AdminMotion.duration(context, AdminMotion.expand),
            curve: AdminMotion.curveStandard,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFFAF7F2),
                      border: Border(
                        top: AdminBorders.sideSubtle,
                        bottom: AdminBorders.sideSubtle,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Workspace Header
                        Row(
                          children: [
                            const Icon(
                              Icons.tune_outlined,
                              size: 14,
                              color: AdminColors.muted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'VARIANT STOCK SPECIFICATIONS',
                                style: AdminTypography.tableHeader.copyWith(
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                  color: AdminColors.muted,
                                ),
                              ),
                            ),
                            if (!isCompact)
                              Text(
                                'Atomic stock management',
                                style: AdminTypography.caption.copyWith(fontSize: 11),
                              ),
                          ],
                        ),
                        const SizedBox(height: AdminSpacing.md),

                        // Variants List or Empty Migration Notice
                        if (product.variants.isEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(AdminSpacing.md),
                            decoration: BoxDecoration(
                              color: AdminColors.white,
                              border: AdminBorders.subtle,
                              borderRadius: AdminRadii.radiusSm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Variant detail unavailable',
                                  style: AdminTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Refresh the live catalogue after applying the Phase 6 migration.',
                                  style: AdminTypography.caption,
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Variant Table Header (Desktop only)
                          if (!isCompact)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: const BoxDecoration(
                                color: AdminColors.white,
                                border: AdminBorders.subtle,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(AdminRadii.sm),
                                  topRight: Radius.circular(AdminRadii.sm),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  AdminTableHeaderCell(
                                    label: 'Variant Attributes',
                                    flex: 3,
                                  ),
                                  AdminTableHeaderCell(label: 'SKU', flex: 2),
                                  AdminTableHeaderCell(
                                    label: 'Storefront',
                                    width: 110,
                                  ),
                                  AdminTableHeaderCell(
                                    label: 'Stock Status',
                                    width: 140,
                                  ),
                                  AdminTableHeaderCell(
                                    label: 'Quantity',
                                    width: 110,
                                  ),
                                  AdminTableHeaderCell(
                                    label: 'Save',
                                    width: 60,
                                    alignment: Alignment.centerRight,
                                  ),
                                ],
                              ),
                            ),

                          // Variant Rows
                          Container(
                            decoration: BoxDecoration(
                              color: AdminColors.white,
                              border: isCompact
                                  ? AdminBorders.subtle
                                  : const Border(
                                      left: AdminBorders.sideSubtle,
                                      right: AdminBorders.sideSubtle,
                                      bottom: AdminBorders.sideSubtle,
                                    ),
                              borderRadius: isCompact
                                  ? AdminRadii.radiusSm
                                  : const BorderRadius.only(
                                      bottomLeft: Radius.circular(AdminRadii.sm),
                                      bottomRight: Radius.circular(AdminRadii.sm),
                                    ),
                            ),
                            child: Column(
                              children: [
                                for (int i = 0; i < product.variants.length; i++)
                                  _VariantStockRow(
                                    product: product,
                                    variant: product.variants[i],
                                    isCompact: isCompact,
                                    showDivider: i > 0,
                                  ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: AdminSpacing.sm),

                        // Footer: Manage variants link
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AdminColors.charcoal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                            onPressed: () =>
                                context.push('/admin/products/${product.id}/edit'),
                            icon: const Icon(Icons.edit_outlined, size: 15),
                            label: const Text(
                              'Manage variants',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopProductRow(
    BuildContext context,
    bool outOfStock,
    bool lowStock,
    bool hasImage,
  ) {
    return Row(
      children: [
        // Expand/Collapse Chevron
        AnimatedRotation(
          duration: AdminMotion.duration(context, AdminMotion.component),
          curve: AdminMotion.curveStandard,
          turns: isExpanded ? 0.25 : 0,
          child: const Icon(
            Icons.chevron_right,
            size: 20,
            color: AdminColors.muted,
          ),
        ),
        const SizedBox(width: 12),

        // Product Thumbnail & Details
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AdminColors.surfaceSubtle,
                  border: AdminBorders.subtle,
                  borderRadius: AdminRadii.radiusXs,
                ),
                clipBehavior: Clip.antiAlias,
                child: hasImage
                    ? ProductImage(
                        url: product.imageUrl,
                        fit: BoxFit.cover,
                      )
                    : const Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                        color: AdminColors.muted,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.sku,
                      style: AdminTypography.caption.copyWith(
                        color: AdminColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Category
        SizedBox(
          width: 140,
          child: Text(
            product.category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminTypography.body,
          ),
        ),

        // Status (Active / Draft)
        SizedBox(
          width: 100,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AdminBadge(
              label: product.isActive ? 'Active' : 'Draft',
              variant: product.isActive
                  ? AdminBadgeVariant.neutral
                  : AdminBadgeVariant.draft,
            ),
          ),
        ),

        // Total Stock
        SizedBox(
          width: 120,
          child: Text(
            '${product.stockQuantity} units',
            style: AdminTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Stock Health Badge
        SizedBox(
          width: 130,
          child: Align(
            alignment: Alignment.centerLeft,
            child: outOfStock
                ? const AdminBadge.error(
                    label: 'OUT OF STOCK',
                    showDot: true,
                  )
                : lowStock
                    ? AdminBadge.warning(
                        label: 'LOW · ${product.stockQuantity}',
                        showDot: true,
                      )
                    : AdminBadge(
                        label: '${product.stockQuantity} units',
                        variant: AdminBadgeVariant.neutral,
                      ),
          ),
        ),

        // Variants Count Badge
        SizedBox(
          width: 110,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AdminBadge(
              label:
                  '${product.variants.length} ${product.variants.length == 1 ? 'variant' : 'variants'}',
              variant: AdminBadgeVariant.neutral,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactProductRow(
    BuildContext context,
    bool outOfStock,
    bool lowStock,
    bool hasImage,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AnimatedRotation(
              duration: AdminMotion.duration(context, AdminMotion.component),
              curve: AdminMotion.curveStandard,
              turns: isExpanded ? 0.25 : 0,
              child: const Icon(
                Icons.chevron_right,
                size: 20,
                color: AdminColors.muted,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AdminColors.surfaceSubtle,
                border: AdminBorders.subtle,
                borderRadius: AdminRadii.radiusXs,
              ),
              clipBehavior: Clip.antiAlias,
              child: hasImage
                  ? ProductImage(
                      url: product.imageUrl,
                      fit: BoxFit.cover,
                    )
                  : const Icon(
                      Icons.inventory_2_outlined,
                      size: 16,
                      color: AdminColors.muted,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${product.sku} · ${product.category}',
                    style: AdminTypography.caption.copyWith(
                      color: AdminColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AdminSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AdminBadge(
              label: product.isActive ? 'Active' : 'Draft',
              variant: product.isActive
                  ? AdminBadgeVariant.neutral
                  : AdminBadgeVariant.draft,
            ),
            outOfStock
                ? const AdminBadge.error(label: 'OUT OF STOCK', showDot: true)
                : lowStock
                    ? AdminBadge.warning(
                        label: 'LOW · ${product.stockQuantity}',
                        showDot: true,
                      )
                    : Text(
                        '${product.stockQuantity} units',
                        style: AdminTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Variant Stock Row (Real-time stock input, availability switch, atomic save)
// =============================================================================
class _VariantStockRow extends ConsumerStatefulWidget {
  const _VariantStockRow({
    required this.product,
    required this.variant,
    required this.isCompact,
    this.showDivider = true,
  });

  final Product product;
  final ProductVariant variant;
  final bool isCompact;
  final bool showDivider;

  @override
  ConsumerState<_VariantStockRow> createState() => _VariantStockRowState();
}

class _VariantStockRowState extends ConsumerState<_VariantStockRow> {
  late final TextEditingController _stock;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _stock = TextEditingController(text: '${widget.variant.stockQuantity}');
  }

  @override
  void didUpdateWidget(covariant _VariantStockRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variant.stockQuantity != widget.variant.stockQuantity) {
      _stock.text = '${widget.variant.stockQuantity}';
    }
  }

  @override
  void dispose() {
    _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final variant = widget.variant;
    final label = [
      variant.size == 'One Size' ? null : variant.size,
      variant.colorName == 'Standard' ? null : variant.colorName,
    ].whereType<String>().join(' · ');

    final displayLabel = label.isEmpty ? 'Single option' : label;
    final low =
        variant.stockQuantity > 0 && variant.stockQuantity <= lowStockThreshold;
    final isOut = variant.stockQuantity == 0;

    final colorDot = (variant.colorValue != 0xFF000000 &&
            variant.colorName != 'Standard' &&
            variant.colorName.isNotEmpty)
        ? Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: Color(variant.colorValue),
              shape: BoxShape.circle,
              border: Border.all(
                color: AdminColors.charcoal.withAlpha(40),
                width: 0.5,
              ),
            ),
          )
        : null;

    if (widget.isCompact) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: widget.showDivider
              ? const Border(top: AdminBorders.sideSubtle)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ?colorDot,
                Expanded(
                  child: Text(
                    displayLabel,
                    style: AdminTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Switch(
                  value: variant.isAvailable,
                  activeThumbColor: AdminColors.charcoal,
                  onChanged: _saving ? null : _setAvailability,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    variant.sku,
                    style: AdminTypography.caption.copyWith(
                      color: AdminColors.muted,
                    ),
                  ),
                ),
                if (isOut)
                  const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Text(
                      'OUT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.error,
                      ),
                    ),
                  )
                else if (low)
                  const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Text(
                      'LOW',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.warning,
                      ),
                    ),
                  ),
                SizedBox(
                  width: 80,
                  height: 36,
                  child: TextField(
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: AdminTypography.body,
                    onSubmitted: (_) => _save(),
                    decoration: const InputDecoration(
                      labelText: 'Stock',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderSide: AdminBorders.sideSubtle,
                        borderRadius: AdminRadii.radiusSm,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Save stock',
                  iconSize: 18,
                  color: AdminColors.charcoal,
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Desktop Layout
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: widget.showDivider
            ? const Border(top: AdminBorders.sideSubtle)
            : null,
      ),
      child: Row(
        children: [
          // Variant Attributes
          Expanded(
            flex: 3,
            child: Row(
              children: [
                ?colorDot,
                Expanded(
                  child: Text(
                    displayLabel,
                    style: AdminTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // SKU
          Expanded(
            flex: 2,
            child: Text(
              variant.sku,
              style: AdminTypography.caption.copyWith(color: AdminColors.muted),
            ),
          ),

          // Storefront Switch
          SizedBox(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Switch(
                value: variant.isAvailable,
                activeThumbColor: AdminColors.charcoal,
                onChanged: _saving ? null : _setAvailability,
              ),
            ),
          ),

          // Stock Status Badge
          SizedBox(
            width: 140,
            child: Align(
              alignment: Alignment.centerLeft,
              child: isOut
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AdminBadge.error(label: 'OUT OF STOCK', showDot: true),
                        SizedBox(width: 4),
                        Text('OUT', style: TextStyle(fontSize: 0)),
                      ],
                    )
                  : low
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AdminBadge.warning(
                              label: 'LOW · ${variant.stockQuantity}',
                              showDot: true,
                            ),
                            const SizedBox(width: 4),
                            const Text('LOW', style: TextStyle(fontSize: 0)),
                          ],
                        )
                      : const AdminBadge(
                          label: 'OPTIMAL',
                          variant: AdminBadgeVariant.neutral,
                        ),
            ),
          ),

          // Stock Quantity Input
          SizedBox(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 88,
                height: 36,
                child: TextField(
                  controller: _stock,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AdminTypography.body,
                  onSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Stock',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderSide: AdminBorders.sideSubtle,
                      borderRadius: AdminRadii.radiusSm,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: AdminBorders.sideActive,
                      borderRadius: AdminRadii.radiusSm,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Save Action Button
          SizedBox(
            width: 60,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Save stock',
                iconSize: 18,
                color: AdminColors.charcoal,
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final quantity = int.tryParse(_stock.text);
    if (quantity == null || quantity < 0 || widget.variant.id == null) {
      if (mounted) {
        AdminSnackbar.show(
          context,
          message: 'Enter a valid non-negative quantity for a saved variant.',
          isError: true,
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(productRepositoryProvider)
          .setVariantStock(widget.variant.id!, quantity);
      await ref.read(productCatalogProvider.notifier).refresh();
      if (mounted) {
        AdminSnackbar.show(context, message: 'Stock updated.');
      }
    } catch (error) {
      if (mounted) {
        AdminSnackbar.show(
          context,
          message: 'Stock could not be updated: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setAvailability(bool value) async {
    final id = widget.variant.id;
    if (id == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(productRepositoryProvider)
          .setVariantStock(id, null, isAvailable: value);
      await ref.read(productCatalogProvider.notifier).refresh();
    } catch (error) {
      if (mounted) {
        AdminSnackbar.show(
          context,
          message: 'Availability could not be updated: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
