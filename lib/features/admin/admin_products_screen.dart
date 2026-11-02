import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/norve_theme.dart';
import '../../core/supabase/supabase_providers.dart';
import '../products/product_catalog_provider.dart';
import '../products/product_repository.dart';
import '../products/widgets/catalog_state_notice.dart';
import 'admin_metrics.dart';

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
      final matchesQuery = '${product.name} ${product.sku} ${product.category}'
          .toLowerCase()
          .contains(_query.toLowerCase());
      final matchesCategory =
          _category == 'All categories' || product.category == _category;
      final matchesFilter = switch (_filter) {
        'Active' => product.isActive,
        'Draft' => !product.isActive,
        'In stock' => product.isPurchasable,
        'Out of stock' => !product.isPurchasable,
        'Low stock' => product.stockQuantity <= lowStockThreshold,
        _ => true,
      };
      return matchesQuery && matchesCategory && matchesFilter;
    }).toList();

    return SafeArea(
      child: CustomScrollView(
        key: const ValueKey('admin-products-scroll'),
        slivers: [
          const SliverToBoxAdapter(child: CatalogStateNotice()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Products',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('admin-add-product'),
                        onPressed: () => context.push('/admin/products/new'),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add product'),
                        style: FilledButton.styleFrom(
                          backgroundColor: NorveColors.charcoal,
                          foregroundColor: NorveColors.white,
                          shape: const RoundedRectangleBorder(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage the shared customer catalogue.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: NorveColors.muted),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final search = TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                          hintText: 'Search products',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      );
                      final filter = DropdownButtonFormField<String>(
                        key: ValueKey(_filter),
                        initialValue: _filter,
                        decoration: const InputDecoration(
                          labelText: 'Filter',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
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
                            value: 'Draft',
                            child: Text('Draft'),
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
                        onChanged: (value) =>
                            setState(() => _filter = value ?? 'All products'),
                      );
                      final category = DropdownButtonFormField<String>(
                        key: ValueKey('products-category-$_category'),
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items:
                            <String>[
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
                        onChanged: (value) => setState(
                          () => _category = value ?? 'All categories',
                        ),
                      );
                      if (constraints.maxWidth < 720) {
                        return Column(
                          children: [
                            search,
                            const SizedBox(height: 10),
                            filter,
                            const SizedBox(height: 10),
                            category,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: search),
                          const SizedBox(width: 12),
                          SizedBox(width: 180, child: filter),
                          const SizedBox(width: 12),
                          SizedBox(width: 190, child: category),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (visibleProducts.isEmpty &&
              (catalogStatus.phase == CatalogPhase.live ||
                  catalogStatus.phase == CatalogPhase.development))
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('No products match this search.')),
            )
          else if (visibleProducts.isNotEmpty)
            SliverList.separated(
              itemCount: visibleProducts.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final product = visibleProducts[index];
                return Material(
                  color: NorveColors.ivory,
                  child: ListTile(
                    onTap: () =>
                        context.push('/admin/products/${product.id}/edit'),
                    title: Text(product.name),
                    subtitle: Text(
                      '${product.sku} · ${product.category} · ${product.formattedPrice} · ${product.stockQuantity} in stock',
                    ),
                    leading: Icon(
                      product.isActive
                          ? Icons.check_circle_outline
                          : Icons.pause_circle_outline,
                    ),
                    trailing: Wrap(
                      spacing: 2,
                      children: [
                        IconButton(
                          tooltip: 'Edit ${product.name}',
                          onPressed: () => context.push(
                            '/admin/products/${product.id}/edit',
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Delete ${product.name}',
                          onPressed: () =>
                              _confirmDelete(product.id, product.name),
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String productId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          '“$name” will be removed from the catalogue. Historical order item snapshots are retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete product'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await ref.read(productCatalogProvider.notifier).delete(productId);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Product deleted.')));
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }
  }
}
