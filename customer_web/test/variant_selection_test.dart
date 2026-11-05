import 'package:flutter_test/flutter_test.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve_customer_web/catalog/variant_selection.dart';

ProductVariant variant(
  String size,
  String color, {
  int stock = 5,
  bool available = true,
  int? price,
}) => ProductVariant(
  id: '$size-$color',
  size: size,
  colorName: color,
  colorValue: 0xFF000000,
  stockQuantity: stock,
  isAvailable: available,
  priceOverride: price,
);

Product product(
  List<ProductVariant> variants, {
  bool requiresSize = true,
  bool requiresColor = true,
  int stock = 0,
}) => Product(
  id: 'p',
  name: 'Piece',
  price: 1000,
  imageUrl: '',
  category: 'C',
  description: '',
  requiresSize: requiresSize,
  requiresColor: requiresColor,
  stockQuantity: stock,
  variants: variants,
  sizes: {
    for (final v in variants)
      if (v.size != 'One Size') v.size,
  }.toList(),
  colors: {
    for (final v in variants)
      if (v.colorName != 'Standard') v.colorName,
  }.map((name) => ProductColor(name, 0xFF000000)).toList(),
);

void main() {
  group('the mobile lock-up case: first colour out of stock', () {
    final rules = VariantRules(
      product([
        variant('S', 'Black', stock: 0),
        variant('M', 'Black', stock: 0),
        variant('S', 'White'),
        variant('M', 'White'),
      ]),
    );

    test('starts on the first colour in stock', () {
      expect(rules.initial().color, 'White');
    });

    test('every in-stock option is enabled', () {
      expect(rules.isSizeEnabled('S'), isTrue);
      expect(rules.isSizeEnabled('M'), isTrue);
      expect(rules.isColorEnabled('White'), isTrue);
      expect(rules.isColorEnabled('Black'), isFalse);
    });

    test('the customer can finish the purchase', () {
      final selection = rules.selectSize(rules.initial(), 'M');
      expect(rules.variantFor(selection)?.id, 'M-White');
      expect(rules.canAddToBag(selection), isTrue);
    });
  });

  test('colours are enabled before a size is chosen', () {
    final rules = VariantRules(
      product([variant('S', 'Black'), variant('S', 'White')]),
    );
    expect(rules.initial().size, isNull);
    expect(rules.isColorEnabled('Black'), isTrue);
    expect(rules.isColorEnabled('White'), isTrue);
  });

  group('partial size and colour combinations', () {
    final rules = VariantRules(
      product([
        variant('S', 'Black'),
        variant('M', 'White'),
        variant('L', 'Black', stock: 0),
      ]),
    );

    test('a size only in another colour moves to that colour', () {
      final selection = rules.selectSize(
        const VariantSelection(color: 'Black'),
        'M',
      );
      expect(selection.size, 'M');
      expect(selection.color, 'White');
      expect(rules.canAddToBag(selection), isTrue);
    });

    test('a size available in the current colour keeps that colour', () {
      final selection = rules.selectSize(
        const VariantSelection(color: 'Black'),
        'S',
      );
      expect(selection.color, 'Black');
    });

    test('a colour without the current size clears the size', () {
      final selection = rules.selectColor(
        const VariantSelection(size: 'S', color: 'Black'),
        'White',
      );
      expect(selection.size, isNull);
      expect(selection.color, 'White');
      expect(rules.isSizeMissing(selection), isTrue);
    });

    test('a colour with the current size keeps the size', () {
      final both = VariantRules(
        product([variant('S', 'Black'), variant('S', 'White')]),
      );
      final selection = both.selectColor(
        const VariantSelection(size: 'S', color: 'Black'),
        'White',
      );
      expect(selection.size, 'S');
    });

    test('a size with no stock anywhere is disabled', () {
      expect(rules.isSizeEnabled('L'), isFalse);
    });
  });

  test('every in-stock variant can be reached from the start', () {
    final variants = [
      variant('S', 'Black', stock: 0),
      variant('S', 'White'),
      variant('M', 'Black'),
      variant('M', 'White', available: false),
      variant('L', 'Olive'),
    ];
    final rules = VariantRules(product(variants));
    for (final target in variants.where(
      (v) => v.isAvailable && v.stockQuantity > 0,
    )) {
      final byColorFirst = rules.selectSize(
        rules.selectColor(rules.initial(), target.colorName),
        target.size,
      );
      expect(rules.variantFor(byColorFirst)?.id, target.id);
      expect(rules.canAddToBag(byColorFirst), isTrue);
    }
  });

  test('unavailable variants count as out of stock', () {
    final rules = VariantRules(
      product([variant('S', 'Black', available: false)]),
    );
    expect(rules.isSizeEnabled('S'), isFalse);
    expect(rules.canPurchaseAnything, isFalse);
    expect(rules.canAddToBag(rules.initial()), isFalse);
  });

  test('a fully sold-out product cannot be added', () {
    final rules = VariantRules(
      product([
        variant('S', 'Black', stock: 0),
        variant('M', 'Black', stock: 0),
      ]),
    );
    final selection = rules.selectSize(rules.initial(), 'S');
    expect(rules.canAddToBag(rules.initial()), isFalse);
    expect(rules.canAddToBag(selection), isFalse);
  });

  group('price and stock', () {
    final rules = VariantRules(
      product([
        variant('S', 'Black', price: 1500, stock: 3),
        variant('M', 'Black'),
      ]),
    );

    test('uses the base price until a variant with an override is chosen', () {
      expect(rules.unitPrice(rules.initial()), 1000);
      final selection = rules.selectSize(rules.initial(), 'S');
      expect(rules.unitPrice(selection), 1500);
    });

    test('a variant without an override uses the base price', () {
      expect(rules.unitPrice(rules.selectSize(rules.initial(), 'M')), 1000);
    });

    test('caps quantity at the selected variant stock', () {
      expect(rules.stockLimit(rules.selectSize(rules.initial(), 'S')), 3);
    });
  });

  group('products without a size choice', () {
    final oneSize = VariantRules(
      product([variant('One Size', 'Black')], requiresSize: false),
    );

    test('only need a colour', () {
      expect(oneSize.choosesSize, isFalse);
      final selection = oneSize.initial();
      expect(oneSize.isSizeMissing(selection), isFalse);
      expect(oneSize.variantFor(selection)?.id, 'One Size-Black');
      expect(oneSize.bagSize(selection), 'One Size');
      expect(oneSize.bagColor(selection), 'Black');
    });

    test('require-size data with only "One Size" is not stuck', () {
      final rules = VariantRules(product([variant('One Size', 'Black')]));
      expect(rules.choosesSize, isFalse);
      expect(rules.canAddToBag(rules.initial()), isTrue);
      expect(rules.bagSize(rules.initial()), 'One Size');
    });

    test('products with neither option resolve to the single variant', () {
      final rules = VariantRules(
        product(
          [variant('One Size', 'Standard')],
          requiresSize: false,
          requiresColor: false,
        ),
      );
      final selection = rules.initial();
      expect(rules.canAddToBag(selection), isTrue);
      expect(rules.bagSize(selection), 'One Size');
      expect(rules.bagColor(selection), 'Standard');
    });
  });

  test('bag values come from the chosen variant', () {
    final rules = VariantRules(product([variant('S', 'Black')]));
    final selection = rules.selectSize(rules.initial(), 'S');
    expect(rules.bagSize(selection), 'S');
    expect(rules.bagColor(selection), 'Black');
  });

  test('the prompt state keeps Add to Bag active', () {
    final rules = VariantRules(product([variant('S', 'Black')]));
    expect(rules.isSizeMissing(rules.initial()), isTrue);
    expect(rules.canAddToBag(rules.initial()), isTrue);
  });

  test('a product with no variants and no stock cannot be added', () {
    final rules = VariantRules(product(const []));
    expect(rules.canPurchaseAnything, isFalse);
  });
}
