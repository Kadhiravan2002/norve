import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/norve_theme.dart';
import '../products/product_catalog_provider.dart';
import '../products/widgets/product_grid.dart';
import 'wishlist_provider.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(wishlistProvider);
    final catalog = ref.watch(productCatalogProvider);
    final savedProducts = catalog
        .where((product) => ids.contains(product.id))
        .toList();
    if (savedProducts.isEmpty) {
      return SafeArea(
        child: _EmptyCollection(
          icon: Icons.favorite_border,
          title: 'A little room for something lovely.',
          subtitle: 'Save the pieces you love and find them here whenever you are ready.',
          buttonLabel: 'Continue Shopping',
          onPressed: () => context.go('/'),
        ),
      );
    }
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
              child: Text(
                'Wishlist',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Text(
                '${savedProducts.length} ${savedProducts.length == 1 ? 'piece' : 'pieces'} saved',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: NorveColors.muted),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            sliver: ProductGrid(products: savedProducts),
          ),
        ],
      ),
    );
  }
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 38),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: NorveColors.muted),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(height: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: NorveColors.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: NorveColors.charcoal,
              foregroundColor: NorveColors.white,
              shape: const RoundedRectangleBorder(),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    ),
  );
}
