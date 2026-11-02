import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/norve_theme.dart';
import '../../wishlist/wishlist_provider.dart';
import '../product.dart';
import 'product_image.dart';

class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(
      wishlistProvider.select((ids) => ids.contains(product.id)),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: () => context.push('/product/${product.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 0.76,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(url: product.imageUrl),
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
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(letterSpacing: 1),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: NorveColors.white.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      child: IconButton(
                        key: ValueKey('wishlist-${product.id}'),
                        tooltip: saved
                            ? 'Remove from wishlist'
                            : 'Add to wishlist',
                        onPressed: () => ref
                            .read(wishlistProvider.notifier)
                            .toggle(product.id),
                        icon: Icon(
                          saved ? Icons.favorite : Icons.favorite_border,
                          color: NorveColors.charcoal,
                          size: 19,
                        ),
                        constraints: const BoxConstraints.tightFor(
                          width: 38,
                          height: 38,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500, height: 1.35),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  product.formattedPrice,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                if (product.originalPrice case final regularPrice?) ...[
                  const SizedBox(width: 7),
                  Text(
                    formatInr(regularPrice),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: NorveColors.muted,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
