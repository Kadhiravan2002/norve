import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/products/product_catalog_provider.dart';
import 'package:norve/features/wishlist/wishlist_provider.dart';

import '../app/breakpoints.dart';
import '../shell/storefront_footer.dart';
import '../widgets/catalogue_section.dart';
import '../widgets/storefront_state_view.dart';

class WishlistPage extends ConsumerWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(wishlistProvider);
    final catalogue = ref.watch(productCatalogProvider);
    final status = ref.watch(catalogLoadStateProvider);
    final saved = catalogue.where((item) => ids.contains(item.id)).toList();
    final gutter = StorefrontBreakpoints.gutter(
      MediaQuery.sizeOf(context).width,
    );
    final textTheme = Theme.of(context).textTheme;

    // Saved pieces may still be loading, so only an empty list or a finished
    // load can show the empty message. Unavailable pieces stay hidden.
    final isEmpty =
        ids.isEmpty ||
        resolveCatalogueView(status, saved) == CatalogueView.empty;

    return CustomScrollView(
      slivers: [
        if (isEmpty)
          SliverToBoxAdapter(
            key: const ValueKey('wishlist-empty'),
            child: StorefrontMessageView(
              icon: Icons.favorite_border,
              title: 'A little room for something lovely.',
              message:
                  'Save the pieces you love and find them here whenever you '
                  'are ready.',
              actionLabel: 'Continue Shopping',
              onAction: () => context.go('/'),
            ),
          )
        else ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 32, gutter, 20),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Wishlist', style: textTheme.headlineMedium),
                  if (saved.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${saved.length} ${saved.length == 1 ? 'piece' : 'pieces'} saved',
                      style: textTheme.bodySmall?.copyWith(
                        color: NorveColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          CatalogueSection(products: saved, gutter: gutter),
        ],
        const StorefrontFooterSliver(),
      ],
    );
  }
}
