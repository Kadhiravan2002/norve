import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/norve_theme.dart';
import '../products/product.dart';
import '../products/product_catalog_provider.dart';
import '../products/widgets/product_image.dart';
import 'bag_provider.dart';

class BagScreen extends ConsumerWidget {
  const BagScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(bagProvider);
    final catalog = ref.watch(productCatalogProvider);
    if (items.isEmpty) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 38),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.shopping_bag_outlined,
                  size: 36,
                  color: NorveColors.muted,
                ),
                const SizedBox(height: 22),
                Text(
                  'Your bag is waiting.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Find something considered for your everyday.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: NorveColors.muted, height: 1.5),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/'),
                  style: FilledButton.styleFrom(
                    backgroundColor: NorveColors.charcoal,
                    foregroundColor: NorveColors.white,
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: const Text('Continue Shopping'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final subtotal = ref.watch(bagSubtotalProvider);
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Your Bag',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          Text(
            '${ref.watch(bagItemCountProvider)} items',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: NorveColors.muted),
          ),
        ],
      ),
    );
    final rows = ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 24),
      itemBuilder: (context, index) {
        final matches = catalog.where(
          (product) => product.id == items[index].productId,
        );
        return _BagRow(
          item: items[index],
          product: matches.isEmpty ? null : matches.first,
        );
      },
    );
    final summary = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: const BoxDecoration(
        color: NorveColors.white,
        border: Border(top: BorderSide(color: NorveColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Subtotal',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontFamily: 'Inter'),
                ),
              ),
              Text(
                formatInr(subtotal),
                key: const ValueKey('bag-subtotal'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Taxes and delivery are calculated later.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: NorveColors.muted),
          ),
          const SizedBox(height: 14),
          FilledButton(
            key: const ValueKey('proceed-to-checkout'),
            onPressed: () => context.push('/checkout'),
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
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 1024
            ? Padding(
                padding: const EdgeInsets.all(28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          header,
                          Expanded(child: rows),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                    SizedBox(
                      width: 360,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: NorveColors.white,
                          border: Border.all(color: NorveColors.line),
                        ),
                        child: summary,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  header,
                  Expanded(child: rows),
                  summary,
                ],
              ),
      ),
    );
  }
}

class _BagRow extends ConsumerWidget {
  const _BagRow({required this.item, required this.product});

  final BagItem item;
  final Product? product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(bagProvider.notifier);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          height: 132,
          child: ProductImage(url: product?.imageUrl ?? ''),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product?.name ?? 'Unavailable product',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                productVariantLabel(item.size, item.color).isEmpty
                    ? 'Single option'
                    : productVariantLabel(item.size, item.color),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: NorveColors.muted),
              ),
              const SizedBox(height: 6),
              Text(
                formatInr(item.unitPrice),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _QuantityButton(
                    label: 'Decrease quantity',
                    icon: Icons.remove,
                    onPressed: item.quantity > 1
                        ? () => controller.decrease(item.variantId)
                        : null,
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${item.quantity}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  _QuantityButton(
                    label: 'Increase quantity',
                    icon: Icons.add,
                    onPressed: () => controller.increase(item.variantId),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Remove ${product?.name ?? 'product'}',
                    onPressed: () => controller.remove(item.variantId),
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatInr(item.lineTotal),
          key: ValueKey('line-total-${item.variantId}'),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 30,
    height: 30,
    child: IconButton(
      tooltip: label,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      iconSize: 16,
      icon: Icon(icon),
    ),
  );
}
