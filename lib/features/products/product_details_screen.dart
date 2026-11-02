import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/norve_theme.dart';
import '../bag/bag_provider.dart';
import '../wishlist/wishlist_provider.dart';
import 'product.dart';
import 'widgets/product_image.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  const ProductDetailsScreen({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  late final PageController _galleryController;
  late List<String> _gallery;
  String? _selectedSize;
  late String _selectedColor;
  int _quantity = 1;
  int _galleryIndex = 0;

  @override
  void initState() {
    super.initState();
    _gallery = widget.product.galleryImageUrls.isEmpty
        ? [widget.product.imageUrl]
        : widget.product.galleryImageUrls;
    _galleryController = PageController();
    _selectedSize = widget.product.requiresSize ? null : 'One Size';
    _selectedColor = widget.product.requiresColor
        ? (widget.product.colors.isEmpty
              ? ''
              : widget.product.colors.first.name)
        : 'Standard';
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProductDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product != widget.product) {
      _gallery = widget.product.galleryImageUrls.isEmpty
          ? [widget.product.imageUrl]
          : widget.product.galleryImageUrls;
      if (!widget.product.requiresColor ||
          !widget.product.colors.any((color) => color.name == _selectedColor)) {
        _selectedColor = widget.product.colors.isEmpty
            ? (widget.product.requiresColor ? '' : 'Standard')
            : widget.product.colors.first.name;
      }
      if (!widget.product.requiresSize) {
        _selectedSize = 'One Size';
      } else if (!widget.product.sizes.contains(_selectedSize)) {
        _selectedSize = null;
      }
      _galleryIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final selectedPrice =
        _selectedVariant(product)?.priceOverride ?? product.price;
    final isSaved = ref.watch(
      wishlistProvider.select((ids) => ids.contains(product.id)),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          'NORVÉ',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(letterSpacing: 3.5, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            key: const ValueKey('details-wishlist'),
            tooltip: isSaved ? 'Remove from wishlist' : 'Add to wishlist',
            onPressed: () =>
                ref.read(wishlistProvider.notifier).toggle(product.id),
            icon: Icon(isSaved ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (width < 768) {
            // Keep the established mobile composition and fixed bottom action.
            return CustomScrollView(
              key: const ValueKey('product-details-scroll'),
              slivers: [
                SliverToBoxAdapter(child: _buildGallery(context)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 34),
                  sliver: SliverList.list(
                    children: _buildInformationChildren(
                      context,
                      product,
                      selectedPrice,
                    ),
                  ),
                ),
              ],
            );
          }
          return _buildWideLayout(context, product, selectedPrice, width);
        },
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 768
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(height: 52, child: _addToBagButton(product)),
            )
          : null,
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    Product product,
    int selectedPrice,
    double width,
  ) {
    final isDesktop = width >= 1024;
    final maxContentWidth = isDesktop ? 1440.0 : double.infinity;
    final horizontalPadding = isDesktop ? 32.0 : 20.0;
    return SingleChildScrollView(
      key: const ValueKey('product-details-responsive-scroll'),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: isDesktop ? 7 : 5,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final galleryHeight = isDesktop
                          ? (constraints.maxWidth * 0.72).clamp(500.0, 680.0)
                          : (constraints.maxWidth * 1.08).clamp(320.0, 400.0);
                      return Padding(
                        padding: EdgeInsets.only(top: isDesktop ? 28 : 20),
                        child: _buildResponsiveGallery(galleryHeight),
                      );
                    },
                  ),
                ),
                SizedBox(width: isDesktop ? 52 : 28),
                Expanded(
                  flex: isDesktop ? 5 : 6,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(0, isDesktop ? 42 : 28, 0, 40),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 580),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ..._buildInformationChildren(
                            context,
                            product,
                            selectedPrice,
                            responsive: true,
                            desktop: isDesktop,
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            height: 52,
                            width: double.infinity,
                            child: _addToBagButton(product),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildInformationChildren(
    BuildContext context,
    Product product,
    int selectedPrice, {
    bool responsive = false,
    bool desktop = false,
  }) => [
    Text(
      product.category.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: NorveColors.muted,
        letterSpacing: 1.7,
        fontWeight: FontWeight.w600,
      ),
    ),
    const SizedBox(height: 8),
    Text(
      product.name,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontSize: responsive ? (desktop ? 32 : 26) : 28,
        height: 1.18,
      ),
    ),
    const SizedBox(height: 10),
    Row(
      children: [
        Text(
          formatInr(selectedPrice),
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
        if (product.originalPrice case final original?
            when original > selectedPrice) ...[
          const SizedBox(width: 9),
          Text(
            formatInr(original),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: NorveColors.muted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      ],
    ),
    const SizedBox(height: 16),
    Text(
      product.description,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(height: 1.65, color: NorveColors.muted),
    ),
    const SizedBox(height: 27),
    if (product.requiresSize) ...[
      _sectionLabel(context, 'SELECT SIZE', trailing: 'Size guide'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        children: [
          for (final size in product.sizes)
            _SizeOption(
              size: size,
              selected: size == _selectedSize,
              enabled: product.variants.isEmpty
                  ? product.stockQuantity > 0
                  : _variantsForSize(product, size).isNotEmpty,
              onTap: () => setState(() {
                _selectedSize = size;
                _quantity = 1;
              }),
            ),
        ],
      ),
      if (_selectedSize == null) ...[
        const SizedBox(height: 8),
        Text(
          'Please select a size to continue.',
          key: const ValueKey('size-required-hint'),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: NorveColors.muted),
        ),
      ],
      const SizedBox(height: 25),
    ],
    if (product.requiresColor) ...[
      _sectionLabel(
        context,
        'COLOR',
        trailing: _selectedColor.isEmpty ? 'Unavailable' : _selectedColor,
      ),
      const SizedBox(height: 13),
      Wrap(
        spacing: 14,
        children: [
          for (final color in product.colors)
            _ColorOption(
              color: color,
              selected: color.name == _selectedColor,
              enabled: product.variants.isEmpty
                  ? product.stockQuantity > 0
                  : _variantsForColor(product, color.name).isNotEmpty,
              onTap: () => setState(() {
                _selectedColor = color.name;
                _quantity = 1;
              }),
            ),
        ],
      ),
      const SizedBox(height: 27),
    ],
    if (_selectedVariant(product) case final variant?
        when !variant.isAvailable || variant.stockQuantity <= 0)
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Text(
          'This selection is currently unavailable.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: NorveColors.muted),
        ),
      ),
    const SizedBox(height: 27),
    _sectionLabel(context, 'QUANTITY'),
    const SizedBox(height: 12),
    _QuantitySelector(
      quantity: _quantity,
      onDecrease: _quantity > 1 ? () => setState(() => _quantity--) : null,
      onIncrease:
          _quantity <
              (_selectedVariant(product)?.stockQuantity ??
                  product.stockQuantity)
          ? () => setState(() => _quantity++)
          : null,
    ),
  ];

  Widget _addToBagButton(Product product) => FilledButton(
    key: const ValueKey('add-to-bag'),
    onPressed: _canAddToBag(product) ? _addToBag : null,
    style: FilledButton.styleFrom(
      backgroundColor: NorveColors.charcoal,
      foregroundColor: NorveColors.white,
      shape: const RoundedRectangleBorder(),
    ),
    child: Text(
      _canAddToBag(product)
          ? 'Add to Bag  ·  ${formatInr((_selectedVariant(product)?.priceOverride ?? product.price) * _quantity)}'
          : 'Currently unavailable',
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: NorveColors.white, fontWeight: FontWeight.w600),
    ),
  );

  Widget _buildGallery(BuildContext context) {
    final height = MediaQuery.sizeOf(context).width < 380 ? 370.0 : 440.0;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            key: const ValueKey('product-gallery'),
            controller: _galleryController,
            itemCount: _gallery.length,
            onPageChanged: (index) => setState(() => _galleryIndex = index),
            itemBuilder: (context, index) =>
                ProductImage(url: _gallery[index], fit: BoxFit.cover),
          ),
          if (_gallery.length > 1)
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < _gallery.length; index++)
                    Container(
                      width: index == _galleryIndex ? 18 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index == _galleryIndex
                            ? NorveColors.white
                            : NorveColors.white.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResponsiveGallery(double height) => SizedBox(
    height: height,
    child: ColoredBox(
      color: NorveColors.ivory,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            key: const ValueKey('product-gallery'),
            controller: _galleryController,
            itemCount: _gallery.length,
            onPageChanged: (index) => setState(() => _galleryIndex = index),
            itemBuilder: (context, index) =>
                ProductImage(url: _gallery[index], fit: BoxFit.contain),
          ),
          if (_gallery.length > 1)
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < _gallery.length; index++)
                    Container(
                      width: index == _galleryIndex ? 18 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index == _galleryIndex
                            ? NorveColors.charcoal
                            : NorveColors.muted.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );

  Widget _sectionLabel(
    BuildContext context,
    String title, {
    String? trailing,
  }) => Row(
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(letterSpacing: 1.25, fontWeight: FontWeight.w600),
      ),
      const Spacer(),
      if (trailing != null)
        Text(
          trailing,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: NorveColors.muted),
        ),
    ],
  );

  void _addToBag() {
    final product = widget.product;
    final variant = _selectedVariant(product);
    if ((product.requiresSize && _selectedSize == null) ||
        (product.requiresColor && _selectedColor.isEmpty)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              product.requiresSize && _selectedSize == null
                  ? 'Please select a size first.'
                  : 'Please select a colour first.',
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          ),
        );
      return;
    }
    if (!_canAddToBag(product)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('This selection is currently unavailable.'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          ),
        );
      return;
    }
    ref
        .read(bagProvider.notifier)
        .add(
          product,
          size: product.requiresSize ? _selectedSize! : 'One Size',
          color: product.requiresColor ? _selectedColor : 'Standard',
          quantity: _quantity,
          unitPrice: variant?.priceOverride ?? product.price,
          stockLimit: variant?.stockQuantity ?? product.stockQuantity,
          selectedVariantId: variant?.id,
        );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          content: Text('${widget.product.name} added to your bag.'),
          action: SnackBarAction(
            label: 'VIEW BAG',
            textColor: NorveColors.ivory,
            onPressed: () => context.go('/bag'),
          ),
        ),
      );
  }

  bool _canAddToBag(Product product) {
    final missingOption =
        (product.requiresSize && _selectedSize == null) ||
        (product.requiresColor && _selectedColor.isEmpty);
    if (missingOption) {
      return product.variants.isEmpty
          ? product.stockQuantity > 0
          : product.variants.any(
              (variant) => variant.isAvailable && variant.stockQuantity > 0,
            );
    }
    final variant = _selectedVariant(product);
    if (product.variants.isNotEmpty) {
      return variant != null &&
          variant.isAvailable &&
          variant.stockQuantity > 0;
    }
    return product.stockQuantity > 0;
  }

  ProductVariant? _selectedVariant(Product product) {
    for (final variant in product.variants) {
      final sizeMatches =
          !product.requiresSize || variant.size == _selectedSize;
      final colorMatches =
          !product.requiresColor || variant.colorName == _selectedColor;
      if (sizeMatches && colorMatches) return variant;
    }
    return null;
  }

  List<ProductVariant> _variantsForSize(Product product, String size) => product
      .variants
      .where(
        (variant) =>
            variant.size == size &&
            (!product.requiresColor || variant.colorName == _selectedColor) &&
            variant.isAvailable &&
            variant.stockQuantity > 0,
      )
      .toList();

  List<ProductVariant> _variantsForColor(Product product, String color) =>
      product.variants
          .where(
            (variant) =>
                variant.colorName == color &&
                (!product.requiresSize || variant.size == _selectedSize) &&
                variant.isAvailable &&
                variant.stockQuantity > 0,
          )
          .toList();
}

class _SizeOption extends StatelessWidget {
  const _SizeOption({
    required this.size,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String size;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    selected: selected,
    label: enabled ? 'Size $size' : 'Size $size, unavailable',
    child: InkWell(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 55,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? NorveColors.charcoal
              : enabled
              ? Colors.transparent
              : NorveColors.line.withValues(alpha: 0.45),
          border: Border.all(
            color: selected ? NorveColors.charcoal : NorveColors.line,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Text(
                size,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: enabled
                      ? (selected ? NorveColors.white : NorveColors.charcoal)
                      : NorveColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!enabled)
              const Positioned.fill(
                child: CustomPaint(painter: _UnavailableOptionLinePainter()),
              ),
          ],
        ),
      ),
    ),
  );
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ProductColor color;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    selected: selected,
    label: enabled ? color.name : '${color.name}, unavailable',
    child: InkResponse(
      onTap: enabled ? onTap : null,
      radius: 24,
      child: Container(
        width: 32,
        height: 32,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? NorveColors.charcoal : Colors.transparent,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(color.value),
                border: Border.all(color: NorveColors.line),
              ),
            ),
            if (!enabled)
              const Positioned.fill(
                child: CustomPaint(
                  painter: _UnavailableOptionLinePainter(circular: true),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _UnavailableOptionLinePainter extends CustomPainter {
  const _UnavailableOptionLinePainter({this.circular = false});

  final bool circular;

  @override
  void paint(Canvas canvas, Size size) {
    if (circular) canvas.clipPath(Path()..addOval(Offset.zero & size));
    final paint = Paint()
      ..color = NorveColors.muted.withValues(alpha: 0.72)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(3, size.height - 3),
      Offset(size.width - 3, 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _UnavailableOptionLinePainter oldDelegate) =>
      circular != oldDelegate.circular;
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    decoration: BoxDecoration(border: Border.all(color: NorveColors.line)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Decrease quantity',
          onPressed: onDecrease,
          icon: const Icon(Icons.remove, size: 17),
        ),
        SizedBox(
          width: 28,
          child: Text('$quantity', textAlign: TextAlign.center),
        ),
        IconButton(
          tooltip: 'Increase quantity',
          onPressed: onIncrease,
          icon: const Icon(Icons.add, size: 17),
        ),
      ],
    ),
  );
}
