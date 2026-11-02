import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/norve_theme.dart';
import '../../core/supabase/supabase_providers.dart';
import 'product_repository.dart';
import 'product_catalog_provider.dart';
import 'widgets/product_image.dart';
import 'widgets/product_grid.dart';
import 'widgets/store_header.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    this.selectedCategoryId,
    this.newArrivals = false,
  });

  final String? selectedCategoryId;
  final bool newArrivals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogStatus = ref.watch(catalogLoadStateProvider);
    final categories = ref.watch(productCategoriesProvider);
    final loadedCategories = categories.asData?.value;
    final effectiveCategoryId = loadedCategories == null
        ? selectedCategoryId
        : loadedCategories.any((category) => category.id == selectedCategoryId)
        ? selectedCategoryId
        : null;
    final selectedCategory = loadedCategories
        ?.where((category) => category.id == effectiveCategoryId)
        .firstOrNull;
    final shopLocation = effectiveCategoryId == null
        ? '/shop'
        : '/shop?categoryId=${Uri.encodeQueryComponent(effectiveCategoryId)}';
    final activeProducts = ref.watch(
      productCatalogProvider.select((catalog) {
        final filtered = catalog
            .where(
              (product) =>
                  product.isActive &&
                  (effectiveCategoryId == null ||
                      product.categoryId == effectiveCategoryId),
            )
            .toList();
        filtered.sort((a, b) {
          final aDate = a.createdAt;
          final bDate = b.createdAt;
          if (aDate == null) return bDate == null ? 0 : 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
        return filtered;
      }),
    );
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const ValueKey('home-scroll'),
        slivers: [
          const SliverToBoxAdapter(child: StoreHeader()),
          const SliverToBoxAdapter(child: _Hero()),
          SliverToBoxAdapter(
            child: categories.when(
              data: (items) => _CategoryRow(
                categories: items,
                selectedCategoryId: effectiveCategoryId,
                newArrivalsSelected: newArrivals,
                onAll: () => context.go('/'),
                onNewArrivals: () => context.go('/?newArrivals=true'),
                onCategory: (id) =>
                    context.go('/?categoryId=${Uri.encodeQueryComponent(id)}'),
              ),
              loading: () => const _CategoryStatus(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (error, stack) => _CategoryStatus(
                child: TextButton.icon(
                  onPressed: () => ref.invalidate(productCategoriesProvider),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Categories unavailable · Retry'),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      selectedCategory?.name ?? 'Just Arrived',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontSize: 27, fontWeight: FontWeight.w500),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('home-view-all'),
                    onPressed: () => context.go(shopLocation),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward, size: 15),
                    label: Text(
                      'VIEW ALL',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (activeProducts.isEmpty &&
              (catalogStatus.phase == CatalogPhase.loading ||
                  catalogStatus.phase == CatalogPhase.error))
            const SliverToBoxAdapter(child: SizedBox(height: 28))
          else if (activeProducts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'New pieces are on their way.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: ProductGrid(products: activeProducts),
            ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tablet = width >= 768 && width < 1024;
    final desktop = width >= 1024;
    final inset = desktop
        ? 28.0
        : tablet
        ? 22.0
        : 16.0;
    final content = SizedBox(
      height: width < 380
          ? 410
          : desktop
          ? 540
          : tablet
          ? 490
          : 440,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ProductImage(
              url: 'https://images.unsplash.com/photo-1539109136881-3be0616acf4b?auto=format&fit=crop&w=1600&q=90',
            ),
            ColoredBox(color: NorveColors.charcoal.withValues(alpha: 0.30)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                desktop
                    ? 56
                    : tablet
                    ? 38
                    : 24,
                desktop ? 48 : 24,
                desktop
                    ? 56
                    : tablet
                    ? 38
                    : 24,
                desktop ? 48 : 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'THE EVERYDAY EDIT',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: NorveColors.white,
                      letterSpacing: 2.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A New Perspective on Everyday Style',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: NorveColors.white,
                      fontSize: width < 380
                          ? 31
                          : desktop
                          ? 48
                          : tablet
                          ? 42
                          : 36,
                      height: 1.12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Considered essentials. Timeless silhouettes. Made for your everyday.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: NorveColors.white,
                      fontSize: desktop
                          ? 16
                          : tablet
                          ? 15
                          : 13,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 21),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: const ValueKey('discover-collection'),
                      onPressed: () => context.go('/shop'),
                      style: FilledButton.styleFrom(
                        backgroundColor: NorveColors.ivory,
                        foregroundColor: NorveColors.charcoal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: const RoundedRectangleBorder(),
                      ),
                      child: Text(
                        'Discover the Collection',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!tablet && !desktop) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: content,
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: Padding(
          padding: EdgeInsets.fromLTRB(inset, desktop ? 20 : 12, inset, 0),
          child: content,
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.categories,
    required this.selectedCategoryId,
    required this.newArrivalsSelected,
    required this.onAll,
    required this.onNewArrivals,
    required this.onCategory,
  });

  final List<ProductCategory> categories;
  final String? selectedCategoryId;
  final bool newArrivalsSelected;
  final VoidCallback onAll;
  final VoidCallback onNewArrivals;
  final ValueChanged<String> onCategory;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 57,
    child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      scrollDirection: Axis.horizontal,
      itemCount: categories.length + 2 + (categories.isEmpty ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(width: 26),
      itemBuilder: (context, index) {
        final isAll = index == 0;
        final isNewArrivals = index == 1;
        final isEmptyNotice = categories.isEmpty && index == 2;
        final category = isAll || isNewArrivals || isEmptyNotice
            ? null
            : categories[index - 2];
        final selected = isAll
            ? selectedCategoryId == null && !newArrivalsSelected
            : isNewArrivals
            ? newArrivalsSelected
            : category?.id == selectedCategoryId;
        final label = isAll
            ? 'All'
            : isNewArrivals
            ? 'New Arrivals'
            : isEmptyNotice
            ? 'No active categories'
            : category?.name ?? 'No active categories';
        return Center(
          child: Semantics(
            button: !isEmptyNotice,
            selected: selected,
            label: 'Show $label products',
            child: InkWell(
              key: ValueKey(
                isAll
                    ? 'home-category-all'
                    : isNewArrivals
                    ? 'home-category-new-arrivals'
                    : 'home-category-${category?.id ?? 'empty'}',
              ),
              onTap: isEmptyNotice
                  ? null
                  : isAll
                  ? onAll
                  : isNewArrivals
                  ? onNewArrivals
                  : category == null
                  ? null
                  : () => onCategory(category.id),
              borderRadius: BorderRadius.circular(2),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected
                          ? NorveColors.charcoal
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: selected ? NorveColors.charcoal : NorveColors.muted,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _CategoryStatus extends StatelessWidget {
  const _CategoryStatus({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 57, child: Center(child: child));
}
