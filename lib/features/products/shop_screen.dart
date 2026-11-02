import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/norve_theme.dart';
import '../../core/supabase/supabase_providers.dart';
import 'product_catalog_provider.dart';
import 'product_repository.dart';
import 'widgets/product_grid.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key, this.selectedCategoryId});

  final String? selectedCategoryId;

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  final _search = TextEditingController();
  String _sort = 'Newest';
  String _availability = 'Any availability';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(productCatalogProvider);
    final categoryState = ref.watch(productCategoriesProvider);
    final categories = categoryState.asData?.value ?? const <ProductCategory>[];
    const allCategories = '__all_categories__';
    final selectedCategoryId =
        categories.any((category) => category.id == widget.selectedCategoryId)
        ? widget.selectedCategoryId ?? allCategories
        : allCategories;
    final visibleProducts = catalog.where((product) {
      if (!product.isActive) return false;
      final query = _search.text.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty || product.name.toLowerCase().contains(query);
      final matchesCategory =
          selectedCategoryId == allCategories ||
          product.categoryId == selectedCategoryId;
      final inStock = product.variants.isEmpty
          ? product.stockQuantity > 0
          : product.variants.any(
              (variant) => variant.isAvailable && variant.stockQuantity > 0,
            );
      final matchesAvailability = switch (_availability) {
        'In stock' => inStock,
        'Out of stock' => !inStock,
        _ => true,
      };
      return matchesQuery && matchesCategory && matchesAvailability;
    }).toList();
    switch (_sort) {
      case 'Price: low to high':
        visibleProducts.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: high to low':
        visibleProducts.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Newest':
        visibleProducts.sort((a, b) {
          final aDate = a.createdAt;
          final bDate = b.createdAt;
          if (aDate == null || bDate == null) return 0;
          return bDate.compareTo(aDate);
        });
        break;
    }

    return SafeArea(
      child: CustomScrollView(
        key: const ValueKey('shop-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'Shop',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Text(
                '${visibleProducts.length} considered essentials',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: NorveColors.muted),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('shop-search'),
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search pieces',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final filters = [
                        _categoryFilter(
                          selectedCategoryId,
                          allCategories,
                          categories,
                        ),
                        _filter('shop-sort-filter', _sort, const [
                          'Newest',
                          'Price: low to high',
                          'Price: high to low',
                        ], (value) => setState(() => _sort = value)),
                        _filter(
                          'shop-availability-filter',
                          _availability,
                          const [
                            'Any availability',
                            'In stock',
                            'Out of stock',
                          ],
                          (value) => setState(() => _availability = value),
                        ),
                      ];
                      if (constraints.maxWidth < 560) {
                        return Column(
                          children: [
                            for (var index = 0; index < filters.length; index++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: filters[index],
                              ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          for (var index = 0; index < filters.length; index++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index == filters.length - 1 ? 0 : 8,
                                ),
                                child: filters[index],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const ValueKey('shop-clear-filters'),
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.restart_alt, size: 17),
                      label: const Text('Clear filters'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (visibleProducts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    _search.text.isNotEmpty ||
                            selectedCategoryId != allCategories ||
                            _availability != 'Any availability'
                        ? 'No pieces match your search and filters.'
                        : 'New pieces are on their way.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: NorveColors.muted),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: ProductGrid(products: visibleProducts),
            ),
        ],
      ),
    );
  }

  Widget _filter(
    String key,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$key-$value'),
    initialValue: options.contains(value) ? value : options.first,
    decoration: const InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    isExpanded: true,
    menuMaxHeight: 360,
    borderRadius: BorderRadius.circular(4),
    items: [
      for (final option in options)
        DropdownMenuItem(
          value: option,
          child: Text(option, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (next) {
      if (next != null) onChanged(next);
    },
  );

  Widget _categoryFilter(
    String selectedId,
    String allCategories,
    List<ProductCategory> categories,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('shop-category-filter-$selectedId'),
    initialValue: selectedId,
    decoration: const InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    isExpanded: true,
    menuMaxHeight: 360,
    borderRadius: BorderRadius.circular(4),
    items: [
      DropdownMenuItem(
        value: allCategories,
        child: Text('All categories', overflow: TextOverflow.ellipsis),
      ),
      for (final category in categories)
        DropdownMenuItem(
          value: category.id,
          child: Text(category.name, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (nextId) {
      if (nextId == null) return;
      if (nextId == allCategories) {
        context.go('/shop');
      } else {
        context.go('/shop?categoryId=${Uri.encodeQueryComponent(nextId)}');
      }
    },
  );

  void _clearFilters() {
    _search.clear();
    setState(() {
      _sort = 'Newest';
      _availability = 'Any availability';
    });
    context.go('/shop');
  }
}
