import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve/features/products/product_catalog_provider.dart';
import 'package:norve/features/products/widgets/product_grid.dart';

import '../app/breakpoints.dart';
import '../shell/storefront_footer.dart';
import '../widgets/storefront_state_view.dart';

enum CataloguePageKind { home, shop }

enum CatalogueView { loading, error, empty, products }

/// Picks what to show. Already-loaded products stay visible during a refresh
/// or a failed refresh. The development phase means fixture data, which must
/// never reach customers, so it counts as an error whatever the list holds.
CatalogueView resolveCatalogueView(
  CatalogLoadState status,
  List<Product> products,
) {
  if (status.phase == CatalogPhase.development) return CatalogueView.error;
  if (products.isNotEmpty) return CatalogueView.products;
  return switch (status.phase) {
    CatalogPhase.error => CatalogueView.error,
    CatalogPhase.live => CatalogueView.empty,
    _ => CatalogueView.loading,
  };
}

class CataloguePage extends ConsumerWidget {
  const CataloguePage({super.key, required this.kind});

  final CataloguePageKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productCatalogProvider);
    final status = ref.watch(catalogLoadStateProvider);
    final view = resolveCatalogueView(status, products);
    final gutter = StorefrontBreakpoints.gutter(MediaQuery.sizeOf(context).width);
    final textTheme = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, 36, gutter, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kind == CataloguePageKind.home ? 'Just Arrived' : 'Shop',
                  style: textTheme.headlineMedium,
                ),
                if (kind == CataloguePageKind.shop &&
                    view == CatalogueView.products) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${products.length} considered essentials',
                    style: textTheme.bodyMedium?.copyWith(
                      color: NorveColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        switch (view) {
          CatalogueView.products => SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 56),
            sliver: ProductGrid(products: products),
          ),
          CatalogueView.loading => const SliverToBoxAdapter(
            key: ValueKey('catalogue-loading'),
            child: StorefrontLoadingView(label: 'Loading the collection'),
          ),
          CatalogueView.error => SliverToBoxAdapter(
            key: const ValueKey('catalogue-error'),
            child: StorefrontMessageView(
              icon: Icons.cloud_off_outlined,
              title: 'The collection could not be loaded',
              message: 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: status.phase == CatalogPhase.development
                  ? null
                  : () => ref.read(productCatalogProvider.notifier).refresh(),
            ),
          ),
          CatalogueView.empty => const SliverToBoxAdapter(
            key: ValueKey('catalogue-empty'),
            child: StorefrontMessageView(
              icon: Icons.checkroom_outlined,
              title: 'New pieces are on their way.',
              message: 'Please check back soon.',
            ),
          ),
        },
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: StorefrontFooter(),
          ),
        ),
      ],
    );
  }
}
