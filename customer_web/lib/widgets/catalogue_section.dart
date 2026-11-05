import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve/features/products/product_catalog_provider.dart';

import 'store_product_grid.dart';
import 'storefront_state_view.dart';

enum CatalogueView { loading, error, empty, products }

/// Picks what to show. Already-loaded products stay visible during a refresh
/// or a failed refresh. The development phase means fixture data, which must
/// never reach customers, so it counts as an error whatever the list holds.
CatalogueView resolveCatalogueView(
  CatalogLoadState status,
  List<Product> visibleProducts,
) {
  if (status.phase == CatalogPhase.development) return CatalogueView.error;
  if (visibleProducts.isNotEmpty) return CatalogueView.products;
  return switch (status.phase) {
    CatalogPhase.error => CatalogueView.error,
    CatalogPhase.live => CatalogueView.empty,
    _ => CatalogueView.loading,
  };
}

/// The product grid, or its loading, error or empty state, as a sliver.
class CatalogueSection extends ConsumerWidget {
  const CatalogueSection({
    super.key,
    required this.products,
    required this.gutter,
    this.emptyTitle = 'New pieces are on their way.',
    this.emptyMessage = 'Please check back soon.',
  });

  final List<Product> products;
  final double gutter;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(catalogLoadStateProvider);
    return switch (resolveCatalogueView(status, products)) {
      CatalogueView.products => SliverPadding(
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 56),
        sliver: StoreProductGrid(products: products),
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
      CatalogueView.empty => SliverToBoxAdapter(
        key: const ValueKey('catalogue-empty'),
        child: StorefrontMessageView(
          icon: Icons.checkroom_outlined,
          title: emptyTitle,
          message: emptyMessage,
        ),
      ),
    };
  }
}
