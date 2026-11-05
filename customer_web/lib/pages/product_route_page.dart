import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../catalog/storefront_catalog_repository.dart';
import '../widgets/storefront_state_view.dart';
import 'product_details_page.dart';

/// Opens a product directly from its URL, without waiting for the catalogue.
class ProductRoutePage extends ConsumerWidget {
  const ProductRoutePage({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(storefrontProductProvider(productId));
    return product.when(
      skipLoadingOnRefresh: false,
      loading: () => const SingleChildScrollView(
        child: StorefrontLoadingView(label: 'Loading this piece'),
      ),
      error: (error, stackTrace) => SingleChildScrollView(
        child: StorefrontMessageView(
          icon: Icons.cloud_off_outlined,
          title: 'This piece could not be loaded',
          message: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(storefrontProductProvider(productId)),
        ),
      ),
      data: (value) => value == null
          ? SingleChildScrollView(
              child: StorefrontMessageView(
                icon: Icons.checkroom_outlined,
                title: 'Product unavailable',
                message: 'This piece is no longer available.',
                actionLabel: 'Continue Shopping',
                onAction: () => context.go('/shop'),
              ),
            )
          : ProductDetailsPage(key: ValueKey(value.id), product: value),
    );
  }
}
