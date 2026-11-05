import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/features/products/product_catalog_provider.dart';

import '../app/breakpoints.dart';
import '../app/navigation_memory.dart';
import '../catalog/catalog_query.dart';
import '../shell/storefront_footer.dart';
import '../widgets/catalogue_section.dart';
import '../widgets/category_row.dart';
import '../widgets/home_hero.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({
    super.key,
    required this.location,
    this.selectedCategoryId,
    this.newArrivals = false,
  });

  final String location;
  final String? selectedCategoryId;
  final bool newArrivals;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: ref
        .read(storefrontNavigationMemoryProvider)
        .takeScrollOffset(widget.location),
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(productCatalogProvider);
    final categories = ref.watch(productCategoriesProvider);
    final loaded = categories.asData?.value;
    final width = MediaQuery.sizeOf(context).width;
    final gutter = StorefrontBreakpoints.gutter(width);
    final textTheme = Theme.of(context).textTheme;

    // An unknown category in the URL falls back to everything once loaded.
    final categoryId =
        loaded == null ||
            loaded.any((category) => category.id == widget.selectedCategoryId)
        ? widget.selectedCategoryId
        : null;
    final category = loaded?.where((item) => item.id == categoryId).firstOrNull;
    final showNewArrivals = widget.newArrivals && categoryId == null;

    final products = showNewArrivals
        ? newArrivals(catalogue)
        : newestProducts(
            catalogue.where(
              (product) =>
                  categoryId == null || product.categoryId == categoryId,
            ),
          );

    return CustomScrollView(
      key: const ValueKey('home-scroll'),
      controller: _scroll,
      slivers: [
        const SliverToBoxAdapter(child: HomeHero()),
        SliverToBoxAdapter(
          child: categories.when(
            data: (items) => CategoryRow(
              categories: items,
              selectedCategoryId: categoryId,
              newArrivalsSelected: showNewArrivals,
            ),
            loading: () => const SizedBox(
              height: 57,
              child: Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (error, stack) => SizedBox(
              height: 57,
              child: Center(
                child: TextButton.icon(
                  onPressed: () => ref.invalidate(productCategoriesProvider),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Categories unavailable · Retry'),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, 32, gutter, 20),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    category?.name ??
                        (showNewArrivals ? 'New Arrivals' : 'Just Arrived'),
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('home-view-all'),
                  onPressed: () => context.go(
                    CatalogQuery(categoryId: categoryId).toLocation(),
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward, size: 15),
                  label: Text(
                    'VIEW ALL',
                    style: textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        CatalogueSection(products: products, gutter: gutter),
        const StorefrontFooterSliver(),
      ],
    );
  }
}
