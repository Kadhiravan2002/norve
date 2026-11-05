import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/bag/bag_provider.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve/features/products/product_catalog_provider.dart';
import 'package:norve/features/products/widgets/product_image.dart';
import 'package:url_launcher/link.dart';

import '../app/breakpoints.dart';
import '../app/navigation_memory.dart';
import '../shell/storefront_footer.dart';
import '../widgets/storefront_state_view.dart';

class BagPage extends ConsumerWidget {
  const BagPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(bagProvider);
    final catalogue = ref.watch(productCatalogProvider);
    final status = ref.watch(catalogLoadStateProvider);
    final width = MediaQuery.sizeOf(context).width;
    final gutter = StorefrontBreakpoints.gutter(width);

    if (items.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            key: const ValueKey('bag-empty'),
            child: StorefrontMessageView(
              icon: Icons.shopping_bag_outlined,
              title: 'Your bag is waiting.',
              message: 'Find something considered for your everyday.',
              actionLabel: 'Continue Shopping',
              onAction: () => context.go('/'),
            ),
          ),
          const StorefrontFooterSliver(),
        ],
      );
    }

    final count = ref.watch(bagItemCountProvider);
    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status.hasError && catalogue.isEmpty) ...[
          const _CatalogueNotice(),
          const SizedBox(height: 16),
        ],
        for (final (index, item) in items.indexed) ...[
          if (index > 0) const Divider(height: 28),
          _BagLine(
            item: item,
            product: catalogue
                .where((product) => product.id == item.productId)
                .firstOrNull,
            loaded: status.phase == CatalogPhase.live,
            failed: status.hasError,
          ),
        ],
      ],
    );
    final summary = _BagSummary(subtotal: ref.watch(bagSubtotalProvider));

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, 32, gutter, 56),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your Bag',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    Text(
                      '$count ${count == 1 ? 'item' : 'items'}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: NorveColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (StorefrontBreakpoints.isDesktop(width))
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: lines),
                      const SizedBox(width: 40),
                      SizedBox(width: 360, child: summary),
                    ],
                  )
                else ...[
                  lines,
                  const SizedBox(height: 24),
                  summary,
                ],
              ],
            ),
          ),
        ),
        const StorefrontFooterSliver(),
      ],
    );
  }
}

class _CatalogueNotice extends ConsumerWidget {
  const _CatalogueNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    children: [
      const Expanded(child: Text('Product details could not be loaded.')),
      TextButton(
        onPressed: () => ref.read(productCatalogProvider.notifier).refresh(),
        child: const Text('Try again'),
      ),
    ],
  );
}

class _BagLine extends ConsumerWidget {
  const _BagLine({
    required this.item,
    required this.product,
    required this.loaded,
    required this.failed,
  });

  final BagItem item;
  final Product? product;

  /// A missing product only means unavailable once the catalogue has loaded.
  final bool loaded;
  final bool failed;

  String get _name {
    if (product != null) return product!.name;
    if (loaded) return 'Unavailable product';
    return failed ? 'Details unavailable' : 'Loading…';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(bagProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final variant = productVariantLabel(item.size, item.color);
    final atLimit = item.quantity >= item.stockLimit;
    final current = product;

    Widget linked(Widget child) => current == null
        ? child
        : Link(
            uri: Uri(path: '/product/${current.id}'),
            builder: (context, followLink) => InkWell(
              onTap: () {
                ref
                    .read(storefrontNavigationMemoryProvider)
                    .rememberProductOrigin('/bag', 0);
                followLink?.call();
              },
              child: child,
            ),
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        linked(
          SizedBox(
            width: 104,
            height: 132,
            child: ProductImage(url: current?.imageUrl ?? ''),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: linked(
                        Text(
                          _name,
                          key: ValueKey('bag-line-name-${item.variantId}'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatInr(item.lineTotal),
                    key: ValueKey('line-total-${item.variantId}'),
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                variant.isEmpty ? 'Single option' : variant,
                style: textTheme.bodySmall?.copyWith(color: NorveColors.muted),
              ),
              const SizedBox(height: 6),
              Text(formatInr(item.unitPrice), style: textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  _QuantityButton(
                    tooltip: 'Decrease quantity',
                    icon: Icons.remove,
                    onPressed: item.quantity > 1
                        ? () => controller.decrease(item.variantId)
                        : null,
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${item.quantity}',
                      key: ValueKey('bag-line-quantity-${item.variantId}'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  _QuantityButton(
                    tooltip: 'Increase quantity',
                    icon: Icons.add,
                    onPressed: atLimit
                        ? null
                        : () => controller.increase(item.variantId),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Remove ${current?.name ?? 'product'}',
                    onPressed: () => controller.remove(item.variantId),
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                ],
              ),
              if (atLimit)
                Text(
                  'Only ${item.stockLimit} available',
                  key: ValueKey('bag-line-limit-${item.variantId}'),
                  style: textTheme.bodySmall?.copyWith(
                    color: NorveColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    iconSize: 16,
    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
    padding: EdgeInsets.zero,
    icon: Icon(icon),
  );
}

class _BagSummary extends StatelessWidget {
  const _BagSummary({required this.subtotal});

  final int subtotal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NorveColors.white,
        border: Border.all(color: NorveColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Subtotal', style: textTheme.bodyLarge)),
              Text(
                formatInr(subtotal),
                key: const ValueKey('bag-subtotal'),
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Taxes and delivery are calculated later.',
            style: textTheme.bodySmall?.copyWith(color: NorveColors.muted),
          ),
          const SizedBox(height: 14),
          FilledButton(
            key: const ValueKey('proceed-to-checkout'),
            onPressed: () => context.go('/checkout'),
            style: FilledButton.styleFrom(
              backgroundColor: NorveColors.charcoal,
              foregroundColor: NorveColors.white,
              minimumSize: const Size.fromHeight(48),
              shape: const RoundedRectangleBorder(),
            ),
            child: const Text('Proceed to Checkout'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go('/'),
            style: OutlinedButton.styleFrom(
              foregroundColor: NorveColors.charcoal,
              side: const BorderSide(color: NorveColors.charcoal),
              shape: const RoundedRectangleBorder(),
            ),
            child: const Text('Continue Shopping'),
          ),
        ],
      ),
    );
  }
}
