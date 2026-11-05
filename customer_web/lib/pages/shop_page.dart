import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/products/product_catalog_provider.dart';
import 'package:norve/features/products/product_repository.dart';

import '../app/breakpoints.dart';
import '../app/navigation_memory.dart';
import '../catalog/catalog_query.dart';
import '../shell/storefront_footer.dart';
import '../widgets/catalogue_section.dart';
import '../widgets/shop_filters.dart';

/// Passed as route `extra` to place the cursor in the search field. Using
/// `extra` keeps it out of the URL, so a reload doesn't repeat it.
const focusShopSearch = 'focus-shop-search';

class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({
    super.key,
    required this.location,
    required this.query,
    this.focusSearch = false,
  });

  final String location;
  final CatalogQuery query;
  final bool focusSearch;

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  late final _search = TextEditingController(text: widget.query.search);
  final _searchFocus = FocusNode(debugLabel: 'shop-search');
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: ref
        .read(storefrontNavigationMemoryProvider)
        .takeScrollOffset(widget.location),
  );
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.focusSearch) _requestSearchFocus();
  }

  @override
  void didUpdateWidget(covariant ShopPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the field in step with Back and Forward, unless the customer is
    // part-way through typing.
    final typing = _searchDebounce?.isActive ?? false;
    if (!typing && widget.query.search != _search.text.trim()) {
      _search.text = widget.query.search;
    }
    if (widget.focusSearch && !oldWidget.focusSearch) _requestSearchFocus();
  }

  void _requestSearchFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Filters apply as the customer types. The URL follows after a pause and
  /// without a history entry, so Back doesn't replay every keystroke.
  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final location = widget.query.copyWith(search: value).toLocation();
      Router.neglect(context, () => context.go(location));
    });
  }

  void _apply(CatalogQuery query) {
    _searchDebounce?.cancel();
    context.go(query.copyWith(search: _search.text).toLocation());
  }

  void _clear() {
    _searchDebounce?.cancel();
    _search.clear();
    context.go('/shop');
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(productCatalogProvider);
    final status = ref.watch(catalogLoadStateProvider);
    final loadedCategories = ref.watch(productCategoriesProvider).asData?.value;
    final categories = loadedCategories ?? const <ProductCategory>[];
    final width = MediaQuery.sizeOf(context).width;
    final gutter = StorefrontBreakpoints.gutter(width);
    final desktop = StorefrontBreakpoints.isDesktop(width);
    final textTheme = Theme.of(context).textTheme;

    // An unknown category in the URL falls back to everything once loaded.
    final knownCategory =
        loadedCategories == null ||
        loadedCategories.any((item) => item.id == widget.query.categoryId);
    final query = widget.query.copyWith(
      search: _search.text,
      categoryId: knownCategory ? null : () => null,
    );
    final products = query.apply(catalogue);
    final view = resolveCatalogueView(status, products);

    final searchField = TextField(
      key: const ValueKey('shop-search'),
      controller: _search,
      focusNode: _searchFocus,
      onChanged: _onSearchChanged,
      textInputAction: TextInputAction.search,
      decoration: const InputDecoration(
        hintText: 'Search pieces',
        prefixIcon: Icon(Icons.search),
        isDense: true,
        filled: true,
        fillColor: NorveColors.white,
      ),
    );

    final clearButton = TextButton.icon(
      key: const ValueKey('shop-clear-filters'),
      onPressed: _clear,
      icon: const Icon(Icons.restart_alt, size: 17),
      label: const Text('Clear filters'),
    );

    return CustomScrollView(
      key: const ValueKey('shop-scroll'),
      controller: _scroll,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, 36, gutter, 20),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shop', style: textTheme.headlineMedium),
                const SizedBox(height: 6),
                if (view != CatalogueView.loading &&
                    view != CatalogueView.error)
                  Text(
                    '${products.length} considered '
                    'essential${products.length == 1 ? '' : 's'}',
                    key: const ValueKey('shop-count'),
                    style: textTheme.bodyMedium?.copyWith(
                      color: NorveColors.muted,
                    ),
                  ),
                const SizedBox(height: 20),
                if (desktop)
                  Row(
                    children: [
                      Expanded(flex: 4, child: searchField),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 7,
                        child: ShopFilterFields(
                          query: query,
                          categories: categories,
                          onChanged: _apply,
                          horizontal: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      clearButton,
                    ],
                  )
                else ...[
                  searchField,
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 4,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('shop-open-filters'),
                        onPressed: () async {
                          final next = await showShopFilterSheet(
                            context,
                            query: query,
                            categories: categories,
                          );
                          if (next != null && mounted) _apply(next);
                        },
                        icon: const Icon(Icons.tune, size: 17),
                        label: Text(
                          query.activeOptionCount == 0
                              ? 'Filters'
                              : 'Filters (${query.activeOptionCount})',
                        ),
                      ),
                      clearButton,
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        CatalogueSection(
          products: products,
          gutter: gutter,
          emptyTitle: query.hasActiveFilters
              ? 'No pieces match your search and filters.'
              : 'New pieces are on their way.',
          emptyMessage: query.hasActiveFilters
              ? 'Try a different search or clear your filters.'
              : 'Please check back soon.',
        ),
        const StorefrontFooterSliver(),
      ],
    );
  }
}
