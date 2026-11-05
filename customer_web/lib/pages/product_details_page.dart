import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/bag/bag_provider.dart';
import 'package:norve/features/products/product.dart';

import '../app/breakpoints.dart';
import '../app/navigation_memory.dart';
import '../catalog/variant_selection.dart';
import '../shell/storefront_footer.dart';
import '../widgets/product_description_view.dart';
import '../widgets/product_gallery.dart';
import '../widgets/store_product_card.dart';
import '../widgets/variant_selectors.dart';

class ProductDetailsPage extends ConsumerStatefulWidget {
  const ProductDetailsPage({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends ConsumerState<ProductDetailsPage> {
  late VariantRules _rules = VariantRules(widget.product);
  late VariantSelection _selection = _rules.initial();
  int _quantity = 1;

  Product get _product => widget.product;

  @override
  void didUpdateWidget(covariant ProductDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product != widget.product) {
      _rules = VariantRules(widget.product);
      _selection = _rules.initial();
      _quantity = 1;
    }
  }

  void _select(VariantSelection selection) => setState(() {
    _selection = selection;
    _quantity = 1;
  });

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(
      ref.read(storefrontNavigationMemoryProvider).productOrigin ?? '/shop',
    );
  }

  void _message(String text, {SnackBarAction? action}) {
    final phone = StorefrontBreakpoints.isPhone(
      MediaQuery.sizeOf(context).width,
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          // Clears the fixed Add to Bag bar on phones.
          margin: EdgeInsets.fromLTRB(16, 0, 16, phone ? 88 : 24),
          content: Text(text),
          action: action,
        ),
      );
  }

  void _addToBag() {
    if (_rules.isSizeMissing(_selection)) {
      _message('Please select a size first.');
      return;
    }
    if (_rules.isColorMissing(_selection)) {
      _message('Please select a colour first.');
      return;
    }
    if (!_rules.canAddToBag(_selection)) {
      _message('This selection is currently unavailable.');
      return;
    }
    final variant = _rules.variantFor(_selection);
    ref
        .read(bagProvider.notifier)
        .add(
          _product,
          size: _rules.bagSize(_selection),
          color: _rules.bagColor(_selection),
          quantity: _quantity,
          unitPrice: _rules.unitPrice(_selection),
          stockLimit: _rules.stockLimit(_selection),
          selectedVariantId: variant?.id,
        );
    _message(
      '${_product.name} added to your bag.',
      action: SnackBarAction(
        label: 'VIEW BAG',
        textColor: NorveColors.ivory,
        onPressed: () => context.go('/bag'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final phone = StorefrontBreakpoints.isPhone(width);
    final desktop = StorefrontBreakpoints.isDesktop(width);
    final gutter = StorefrontBreakpoints.gutter(width);
    final images = _product.galleryImageUrls.isEmpty
        ? [_product.imageUrl]
        : _product.galleryImageUrls;
    final backRow = Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const ValueKey('product-back'),
        onPressed: _goBack,
        icon: const Icon(Icons.arrow_back, size: 17),
        label: const Text('Back'),
      ),
    );

    if (phone) {
      return Column(
        key: const ValueKey('product-details-phone'),
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  sliver: SliverToBoxAdapter(child: backRow),
                ),
                SliverToBoxAdapter(
                  child: ProductGallery(
                    images: images,
                    height: width < 380 ? 370 : 440,
                    compact: true,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 34),
                  sliver: SliverToBoxAdapter(child: _details(context, 28)),
                ),
                const StorefrontFooterSliver(),
              ],
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: NorveColors.ivory,
              border: Border(top: BorderSide(color: NorveColors.line)),
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: _addToBagButton(context),
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      key: const ValueKey('product-details-wide'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter - 8, 12, gutter, 56),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                backRow,
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: desktop ? 7 : 1,
                        child: LayoutBuilder(
                          builder: (context, constraints) => ProductGallery(
                            images: images,
                            height: desktop
                                ? (constraints.maxWidth * 0.86).clamp(
                                    500.0,
                                    720.0,
                                  )
                                : (constraints.maxWidth * 1.2).clamp(
                                    340.0,
                                    480.0,
                                  ),
                            compact: false,
                          ),
                        ),
                      ),
                      SizedBox(width: desktop ? 56 : 28),
                      Expanded(
                        flex: desktop ? 5 : 1,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _details(context, desktop ? 34 : 26),
                              const SizedBox(height: 28),
                              SizedBox(
                                height: 52,
                                width: double.infinity,
                                child: _addToBagButton(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const StorefrontFooterSliver(),
      ],
    );
  }

  Widget _details(BuildContext context, double titleSize) {
    final textTheme = Theme.of(context).textTheme;
    final price = _rules.unitPrice(_selection);
    final original = _product.originalPrice;
    final variant = _rules.variantFor(_selection);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _product.category.toUpperCase(),
                          style: textTheme.labelSmall?.copyWith(
                            color: NorveColors.muted,
                            letterSpacing: 1.7,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _product.name,
                          key: const ValueKey('product-name'),
                          style: textTheme.headlineSmall?.copyWith(
                            fontSize: titleSize,
                            height: 1.18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  StoreWishlistButton(productId: _product.id),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 9,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    formatInr(price),
                    key: const ValueKey('product-price'),
                    style: textTheme.titleMedium?.copyWith(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (original != null && original > price)
                    Text(
                      formatInr(original),
                      style: textTheme.bodyMedium?.copyWith(
                        color: NorveColors.muted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ProductDescriptionView(description: _product.description),
            ],
          ),
        ),
        const SizedBox(height: 27),
        if (_rules.choosesSize) ...[
          _sectionLabel(context, 'SELECT SIZE', trailing: 'Size guide'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final size in _product.sizes)
                SizeOption(
                  size: size,
                  selected: size == _selection.size,
                  enabled: _rules.isSizeEnabled(size),
                  onTap: () => _select(_rules.selectSize(_selection, size)),
                ),
            ],
          ),
          if (_rules.isSizeMissing(_selection)) ...[
            const SizedBox(height: 8),
            Text(
              'Please select a size to continue.',
              key: const ValueKey('size-required-hint'),
              style: textTheme.bodySmall?.copyWith(color: NorveColors.muted),
            ),
          ],
          const SizedBox(height: 25),
        ],
        if (_rules.choosesColor) ...[
          _sectionLabel(
            context,
            'COLOR',
            trailing: _selection.color ?? 'Unavailable',
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in _product.colors)
                ColorOption(
                  color: color,
                  selected: color.name == _selection.color,
                  enabled: _rules.isColorEnabled(color.name),
                  onTap: () =>
                      _select(_rules.selectColor(_selection, color.name)),
                ),
            ],
          ),
          const SizedBox(height: 25),
        ],
        if (variant != null && !_rules.canAddToBag(_selection))
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text(
              'This selection is currently unavailable.',
              style: textTheme.bodySmall?.copyWith(color: NorveColors.muted),
            ),
          ),
        _sectionLabel(context, 'QUANTITY'),
        const SizedBox(height: 12),
        QuantitySelector(
          quantity: _quantity,
          onDecrease: _quantity > 1 ? () => setState(() => _quantity--) : null,
          onIncrease: _quantity < _rules.stockLimit(_selection)
              ? () => setState(() => _quantity++)
              : null,
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String title, {String? trailing}) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(
          title,
          style: textTheme.labelMedium?.copyWith(
            letterSpacing: 1.25,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing,
            style: textTheme.bodySmall?.copyWith(color: NorveColors.muted),
          ),
      ],
    );
  }

  Widget _addToBagButton(BuildContext context) {
    final canAdd = _rules.canAddToBag(_selection);
    final total = _rules.unitPrice(_selection) * _quantity;
    return FilledButton(
      key: const ValueKey('add-to-bag'),
      onPressed: canAdd ? _addToBag : null,
      style: FilledButton.styleFrom(
        backgroundColor: NorveColors.charcoal,
        foregroundColor: NorveColors.white,
        shape: const RoundedRectangleBorder(),
      ),
      child: Text(
        canAdd ? 'Add to Bag  ·  ${formatInr(total)}' : 'Currently unavailable',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: canAdd ? NorveColors.white : NorveColors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
