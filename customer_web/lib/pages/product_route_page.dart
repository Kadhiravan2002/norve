import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/features/products/product_details_screen.dart';

import '../catalog/storefront_catalog_repository.dart';
import '../shell/storefront_header.dart';
import '../widgets/storefront_state_view.dart';

/// Opens a product directly from its URL, without waiting for the catalogue.
///
/// Phase 1 mounts the existing product screen, which has its own app bar.
/// Phase 2 replaces it with the desktop-ready product page.
class ProductRoutePage extends ConsumerWidget {
  const ProductRoutePage({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(storefrontProductProvider(productId));
    return product.when(
      skipLoadingOnRefresh: false,
      loading: () => _frame(
        const StorefrontLoadingView(label: 'Loading this piece'),
      ),
      error: (error, stackTrace) => _frame(
        StorefrontMessageView(
          icon: Icons.cloud_off_outlined,
          title: 'This piece could not be loaded',
          message: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(storefrontProductProvider(productId)),
        ),
      ),
      data: (value) => value == null
          ? _frame(
              StorefrontMessageView(
                icon: Icons.checkroom_outlined,
                title: 'Product unavailable',
                message: 'This piece is no longer available.',
                actionLabel: 'Continue Shopping',
                onAction: () => context.go('/shop'),
              ),
            )
          : ProductDetailsScreen(key: ValueKey(value.id), product: value),
    );
  }

  Widget _frame(Widget child) => Scaffold(
    body: Column(
      children: [
        const StorefrontHeader(showMenu: false),
        const Divider(),
        Expanded(child: SingleChildScrollView(child: child)),
      ],
    ),
  );
}
