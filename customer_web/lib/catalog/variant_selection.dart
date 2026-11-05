import 'package:norve/features/products/product.dart';

/// A customer's current size and colour choice.
class VariantSelection {
  const VariantSelection({this.size, this.color});

  final String? size;
  final String? color;
}

/// Selection rules for the web product page.
///
/// Every in-stock variant stays reachable: an option is enabled if it's in
/// stock in any combination, and choosing it adjusts the other option rather
/// than leaving the customer stuck.
class VariantRules {
  const VariantRules(this.product);

  final Product product;

  bool _purchasable(ProductVariant variant) =>
      variant.isAvailable && variant.stockQuantity > 0;

  /// Products that require an option but only have a placeholder value, such
  /// as "One Size", have nothing for the customer to choose.
  bool get choosesSize => product.requiresSize && product.sizes.isNotEmpty;
  bool get choosesColor => product.requiresColor && product.colors.isNotEmpty;

  /// A product requires a colour but has none to offer, so it can't be bought.
  bool get _missingRequiredOptions =>
      product.variants.isEmpty &&
      ((product.requiresSize && product.sizes.isEmpty) ||
          (product.requiresColor && product.colors.isEmpty));

  bool get canPurchaseAnything {
    if (_missingRequiredOptions) return false;
    return product.variants.isEmpty
        ? product.stockQuantity > 0
        : product.variants.any(_purchasable);
  }

  bool isSizeEnabled(String size) => product.variants.isEmpty
      ? product.stockQuantity > 0
      : product.variants.any((v) => v.size == size && _purchasable(v));

  bool isColorEnabled(String color) => product.variants.isEmpty
      ? product.stockQuantity > 0
      : product.variants.any((v) => v.colorName == color && _purchasable(v));

  /// Starts on the first colour in stock. The size waits for the customer.
  VariantSelection initial() {
    if (!choosesColor) return const VariantSelection();
    final inStock = product.colors
        .where((color) => isColorEnabled(color.name))
        .firstOrNull;
    return VariantSelection(color: (inStock ?? product.colors.first).name);
  }

  bool _combinationInStock(String size, String color) => product.variants.any(
    (v) => v.size == size && v.colorName == color && _purchasable(v),
  );

  /// Keeps the colour if it comes in this size, otherwise moves to the first
  /// colour that does.
  VariantSelection selectSize(VariantSelection current, String size) {
    final color = current.color;
    if (!choosesColor || product.variants.isEmpty) {
      return VariantSelection(size: size, color: color);
    }
    if (color != null && _combinationInStock(size, color)) {
      return VariantSelection(size: size, color: color);
    }
    final fallback = product.colors
        .where((option) => _combinationInStock(size, option.name))
        .firstOrNull;
    return VariantSelection(size: size, color: fallback?.name ?? color);
  }

  /// Keeps the size if it comes in this colour, otherwise clears it so the
  /// customer chooses again from what's available.
  VariantSelection selectColor(VariantSelection current, String color) {
    final size = current.size;
    if (size == null || !choosesSize || product.variants.isEmpty) {
      return VariantSelection(size: size, color: color);
    }
    return VariantSelection(
      size: _combinationInStock(size, color) ? size : null,
      color: color,
    );
  }

  bool isSizeMissing(VariantSelection selection) =>
      choosesSize && selection.size == null;

  bool isColorMissing(VariantSelection selection) =>
      choosesColor && selection.color == null;

  /// The variant this selection points to. Null until the choice is complete,
  /// or when the product has no such variant.
  ProductVariant? variantFor(VariantSelection selection) {
    if (isSizeMissing(selection) || isColorMissing(selection)) return null;
    for (final variant in product.variants) {
      final sizeMatches = !choosesSize || variant.size == selection.size;
      final colorMatches =
          !choosesColor || variant.colorName == selection.color;
      if (sizeMatches && colorMatches) return variant;
    }
    return null;
  }

  bool canAddToBag(VariantSelection selection) {
    if (!canPurchaseAnything) return false;
    // The button stays active so it can prompt for the missing option.
    if (isSizeMissing(selection) || isColorMissing(selection)) return true;
    if (product.variants.isEmpty) return true;
    final variant = variantFor(selection);
    return variant != null && _purchasable(variant);
  }

  int unitPrice(VariantSelection selection) =>
      variantFor(selection)?.priceOverride ?? product.price;

  int stockLimit(VariantSelection selection) =>
      variantFor(selection)?.stockQuantity ?? product.stockQuantity;

  /// The size stored in the bag. A variant's own value always matches what
  /// the server's quote expects.
  String bagSize(VariantSelection selection) =>
      variantFor(selection)?.size ??
      (choosesSize ? selection.size! : 'One Size');

  String bagColor(VariantSelection selection) =>
      variantFor(selection)?.colorName ??
      (choosesColor ? selection.color! : 'Standard');
}
