import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/supabase_providers.dart';
import '../products/product_catalog_provider.dart';
import '../products/product_repository.dart';
import '../products/widgets/catalog_state_notice.dart';
import 'admin_metrics.dart';
import 'widgets/admin_widgets.dart';

/// Redesigned NORVÉ Admin Product Listing Screen (`/admin/products`).
///
/// Combines the responsive product-card grid and color swatch presentation from
/// the primary NETIC reference with the restrained architectural borders,
/// luxury editorial typography and balanced spacing of the secondary Wolfpixel reference.
class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() =>
      _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  final _searchController = TextEditingController();
  String _filter = 'All products';
  String _category = 'All categories';
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(productCatalogProvider);
    final catalogStatus = ref.watch(catalogLoadStateProvider);
    final categories =
        ref.watch(productCategoriesProvider).asData?.value ??
        const <ProductCategory>[];

    final visibleProducts = catalog.where((product) {
      final matchesQuery = _query.isEmpty ||
          '${product.name} ${product.sku} ${product.category}'
              .toLowerCase()
              .contains(_query.toLowerCase());
      final matchesCategory =
          _category == 'All categories' || product.category == _category;
      final matchesFilter = switch (_filter) {
        'Active' => product.isActive,
        'Inactive' || 'Draft' => !product.isActive,
        'In stock' => product.isPurchasable,
        'Out of stock' => !product.isPurchasable,
        'Low stock' => product.stockQuantity <= lowStockThreshold,
        _ => true,
      };
      return matchesQuery && matchesCategory && matchesFilter;
    }).toList();

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final int crossAxisCount = width >= 1150
              ? 4
              : width >= 750
                  ? 3
                  : width >= 480
                      ? 2
                      : 1;

          return CustomScrollView(
            key: const ValueKey('admin-products-scroll'),
            slivers: [
              const SliverToBoxAdapter(child: CatalogStateNotice()),
              SliverToBoxAdapter(
                child: AdminPageHeader(
                  title: 'Products',
                  subtitle: 'Manage your boutique catalogue.',
                  actions: [
                    AdminButton.primary(
                      key: const ValueKey('admin-add-product'),
                      label: 'Add product',
                      icon: const Icon(Icons.add, size: 16),
                      onPressed: () => context.push('/admin/products/new'),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _buildSearchAndFilterToolbar(
                    context,
                    width,
                    categories,
                  ),
                ),
              ),
              if (catalogStatus.phase == CatalogPhase.loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AdminLoading(message: 'Loading boutique catalogue...'),
                )
              else if (visibleProducts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AdminEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: _hasActiveFilters
                        ? 'No Matching Products'
                        : 'Catalogue is Empty',
                    message: _hasActiveFilters
                        ? 'No products match the selected search and filter criteria.'
                        : 'Get started by creating your first luxury product for NORVÉ.',
                    actionLabel: _hasActiveFilters
                        ? 'Clear Filters'
                        : 'Add First Product',
                    onAction: _hasActiveFilters
                        ? _resetFilters
                        : () => context.push('/admin/products/new'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      mainAxisExtent: 390,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = visibleProducts[index];
                        return AdminProductCard(
                          key: ValueKey('product-card-${product.id}'),
                          product: product,
                          onTap: () => context.push(
                            '/admin/products/${product.id}/edit',
                          ),
                          onEdit: () => context.push(
                            '/admin/products/${product.id}/edit',
                          ),
                          onDelete: () =>
                              _confirmDelete(product.id, product.name),
                        );
                      },
                      childCount: visibleProducts.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  bool get _hasActiveFilters =>
      _query.isNotEmpty ||
      _filter != 'All products' ||
      _category != 'All categories';

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _query = '';
      _filter = 'All products';
      _category = 'All categories';
    });
  }

  Widget _buildSearchAndFilterToolbar(
    BuildContext context,
    double screenWidth,
    List<ProductCategory> categories,
  ) {
    final search = AdminSearchField(
      controller: _searchController,
      hintText: 'Search products by name, SKU or category...',
      onChanged: (value) => setState(() => _query = value),
      onClear: () => setState(() => _query = ''),
    );

    final statusFilter = AdminFilterDropdown<String>(
      key: ValueKey(_filter),
      value: _filter,
      items: const [
        DropdownMenuItem(
          value: 'All products',
          child: Text('All products'),
        ),
        DropdownMenuItem(
          value: 'Active',
          child: Text('Active'),
        ),
        DropdownMenuItem(
          value: 'Inactive',
          child: Text('Inactive'),
        ),
        DropdownMenuItem(
          value: 'In stock',
          child: Text('In stock'),
        ),
        DropdownMenuItem(
          value: 'Out of stock',
          child: Text('Out of stock'),
        ),
        DropdownMenuItem(
          value: 'Low stock',
          child: Text('Low stock'),
        ),
      ],
      onChanged: (value) => setState(() => _filter = value ?? 'All products'),
    );

    final categoryFilter = AdminFilterDropdown<String>(
      key: ValueKey('products-category-$_category'),
      value: _category,
      items: <String>[
        'All categories',
        ...categories.map((item) => item.name),
      ]
          .map(
            (name) => DropdownMenuItem(
              value: name,
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (value) =>
          setState(() => _category = value ?? 'All categories'),
    );

    if (screenWidth < 750) {
      return Column(
        children: [
          search,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: statusFilter),
              const SizedBox(width: 10),
              Expanded(child: categoryFilter),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: search),
        const SizedBox(width: 12),
        SizedBox(width: 170, child: statusFilter),
        const SizedBox(width: 12),
        SizedBox(width: 190, child: categoryFilter),
      ],
    );
  }

  Future<void> _confirmDelete(String productId, String name) async {
    final confirmed = await AdminConfirmationDialog.show(
      context,
      title: 'Delete product?',
      message:
          '“$name” will be permanently removed from the catalogue. Historical order item snapshots are retained.',
      confirmLabel: 'Delete product',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(productCatalogProvider.notifier).delete(productId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted.')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        }
      }
    }
  }
}
