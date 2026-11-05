import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve/features/products/widgets/product_image.dart';
import 'package:norve/features/wishlist/wishlist_provider.dart';
import 'package:url_launcher/link.dart';

import '../app/navigation_memory.dart';

/// Image height is the card width divided by this.
const storeProductImageAspectRatio = 0.76;

/// Height of the name and price below the image.
const storeProductTextHeight = 84.0;

class StoreProductCard extends ConsumerStatefulWidget {
  const StoreProductCard({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<StoreProductCard> createState() => _StoreProductCardState();
}

class _StoreProductCardState extends ConsumerState<StoreProductCard> {
  bool _hovered = false;
  bool _focused = false;

  void _rememberOrigin(BuildContext context) {
    final location = GoRouter.of(context).routeInformationProvider.value.uri
        .toString();
    ref
        .read(storefrontNavigationMemoryProvider)
        .rememberProductOrigin(
          location,
          Scrollable.maybeOf(context)?.position.pixels ?? 0,
        );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final textTheme = Theme.of(context).textTheme;
    final animate = !MediaQuery.disableAnimationsOf(context);
    final original = product.originalPrice;

    return Stack(
      children: [
        Link(
          uri: Uri(path: '/product/${product.id}'),
          builder: (context, followLink) => InkWell(
            key: ValueKey('product-card-${product.id}'),
            onTap: () {
              _rememberOrigin(context);
              followLink?.call();
            },
            onHover: (value) => setState(() => _hovered = value),
            onFocusChange: (value) => setState(() => _focused = value),
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: NorveInteraction.pressed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: storeProductImageAspectRatio,
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      border: _focused
                          ? Border.all(color: NorveColors.charcoal, width: 2)
                          : null,
                    ),
                    child: ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AnimatedScale(
                            scale: _hovered ? 1.03 : 1,
                            duration: animate
                                ? const Duration(milliseconds: 320)
                                : Duration.zero,
                            curve: Curves.easeOut,
                            child: ProductImage(url: product.imageUrl),
                          ),
                          if (!product.isPurchasable)
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: Container(
                                color: NorveColors.ivory,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                child: Text(
                                  'SOLD OUT',
                                  style: textTheme.labelSmall?.copyWith(
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    decoration: _hovered ? TextDecoration.underline : null,
                    decorationColor: NorveColors.charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 7,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      product.formattedPrice,
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (original != null && original > product.price)
                      Text(
                        formatInr(original),
                        style: textTheme.labelSmall?.copyWith(
                          color: NorveColors.muted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: StoreWishlistButton(productId: product.id),
        ),
      ],
    );
  }
}

class StoreWishlistButton extends ConsumerWidget {
  const StoreWishlistButton({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(
      wishlistProvider.select((ids) => ids.contains(productId)),
    );
    return Material(
      color: NorveColors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: IconButton(
        key: ValueKey('wishlist-$productId'),
        tooltip: saved ? 'Remove from wishlist' : 'Add to wishlist',
        onPressed: () => ref.read(wishlistProvider.notifier).toggle(productId),
        icon: Icon(
          saved ? Icons.favorite : Icons.favorite_border,
          color: NorveColors.charcoal,
          size: 19,
        ),
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
