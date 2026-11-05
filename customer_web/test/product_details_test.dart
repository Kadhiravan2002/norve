import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/features/bag/bag_provider.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve_customer_web/app/navigation_memory.dart';

import 'support/harness.dart';

const _black = ProductColor('Black', 0xFF24211E);
const _white = ProductColor('White', 0xFFFFFFFF);

Product _variantProduct({
  List<ProductVariant>? variants,
  int price = 2000,
  int? originalPrice,
  String description = 'Plain copy.',
  List<String> gallery = const [],
}) {
  final items =
      variants ??
      [
        testVariant('S', 'Black', stock: 0),
        testVariant('M', 'Black', stock: 0),
        testVariant('S', 'White', stock: 3),
        testVariant('M', 'White', stock: 5, price: 2500),
      ];
  return testProduct(
    name: 'Selector Shirt',
    price: price,
    originalPrice: originalPrice,
    description: description,
    variants: items,
    sizes: {for (final v in items) v.size}.toList(),
    colors: const [_black, _white],
    requiresSize: true,
    requiresColor: true,
    gallery: gallery,
    stock: items.fold(0, (sum, v) => sum + v.stockQuantity),
  );
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  Product? product, {
  Size size = const Size(1280, 1400),
}) async {
  final container = await pumpStorefront(
    tester,
    catalogue: () async => const [],
    directProduct: product,
    location: '/product/$testProductId',
    size: size,
  );
  await settle(tester);
  return container;
}

String _priceText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('product-price'))).data!;

Finder _size(String size) => find.byKey(ValueKey('size-option-$size'));
Finder _color(String color) => find.byKey(ValueKey('color-option-$color'));
final _addToBag = find.byKey(const ValueKey('add-to-bag'));

void main() {
  group('page states', () {
    testWidgets('opens directly with the site header', (tester) async {
      await _open(tester, _variantProduct());
      expect(find.text('Selector Shirt'), findsOneWidget);
      expect(find.byKey(const ValueKey('storefront-header')), findsOneWidget);
    });

    testWidgets('a missing product shows the unavailable message', (
      tester,
    ) async {
      final container = await _open(tester, null);
      expect(find.text('Product unavailable'), findsOneWidget);
      await tester.tap(find.text('Continue Shopping'));
      await settle(tester);
      expect(currentUri(container).path, '/shop');
    });
  });

  group('variant selection', () {
    testWidgets('the mobile lock-up case can complete a purchase', (
      tester,
    ) async {
      // The first colour, Black, has no stock at all.
      final container = await _open(tester, _variantProduct());
      expect(find.text('White'), findsOneWidget);
      expect(find.byKey(const ValueKey('size-required-hint')), findsOneWidget);

      await tester.tap(_size('M'));
      await settle(tester);
      expect(find.byKey(const ValueKey('size-required-hint')), findsNothing);

      await tester.tap(_addToBag);
      await settle(tester);
      final bag = container.read(bagProvider);
      expect(bag.single.size, 'M');
      expect(bag.single.color, 'White');
      expect(find.text('Selector Shirt added to your bag.'), findsOneWidget);
    });

    testWidgets('an out-of-stock colour cannot be chosen', (tester) async {
      await _open(tester, _variantProduct());
      await tester.tap(_color('Black'));
      await settle(tester);
      expect(find.text('White'), findsOneWidget);
    });

    testWidgets('a size only in another colour moves to that colour', (
      tester,
    ) async {
      await _open(
        tester,
        _variantProduct(
          variants: [testVariant('S', 'Black'), testVariant('M', 'White')],
        ),
      );
      expect(find.text('Black'), findsOneWidget);
      await tester.tap(_size('M'));
      await settle(tester);
      expect(find.text('White'), findsOneWidget);
    });

    testWidgets('a colour without the size clears it and prompts again', (
      tester,
    ) async {
      await _open(
        tester,
        _variantProduct(
          variants: [testVariant('S', 'Black'), testVariant('M', 'White')],
        ),
      );
      await tester.tap(_size('S'));
      await settle(tester);
      expect(find.byKey(const ValueKey('size-required-hint')), findsNothing);
      await tester.tap(_color('White'));
      await settle(tester);
      expect(find.byKey(const ValueKey('size-required-hint')), findsOneWidget);
    });

    testWidgets('size buttons stay compact and side by side', (tester) async {
      await _open(tester, _variantProduct());
      expect(tester.getSize(_size('S')).width, lessThan(120));
      expect(tester.getSize(_size('S')).height, 48);
      expect(
        tester.getTopLeft(_size('S')).dy,
        tester.getTopLeft(_size('M')).dy,
      );
      expect(
        tester.getTopLeft(_size('S')).dx,
        lessThan(tester.getTopLeft(_size('M')).dx),
      );
    });

    testWidgets('prompts for a size instead of adding', (tester) async {
      final container = await _open(tester, _variantProduct());
      await tester.tap(_addToBag);
      await settle(tester);
      expect(find.text('Please select a size first.'), findsOneWidget);
      expect(container.read(bagProvider), isEmpty);
    });

    testWidgets('a sold-out product shows Currently unavailable', (
      tester,
    ) async {
      await _open(
        tester,
        _variantProduct(
          variants: [
            testVariant('S', 'Black', stock: 0),
            testVariant('M', 'White', stock: 0),
          ],
        ),
      );
      expect(find.text('Currently unavailable'), findsOneWidget);
      expect(tester.widget<FilledButton>(_addToBag).onPressed, isNull);
    });

    testWidgets('a price override changes the price and the total', (
      tester,
    ) async {
      await _open(tester, _variantProduct());
      expect(_priceText(tester), '₹2,000');
      await tester.tap(_size('M'));
      await settle(tester);
      expect(_priceText(tester), '₹2,500');
      expect(find.textContaining('Add to Bag'), findsOneWidget);
      expect(find.textContaining('₹2,500'), findsWidgets);
    });

    testWidgets('quantity stops at stock and resets on a variant change', (
      tester,
    ) async {
      await _open(tester, _variantProduct());
      await tester.tap(_size('S'));
      await settle(tester);
      final increase = find.byKey(const ValueKey('quantity-increase'));
      await tester.tap(increase);
      await tester.tap(increase);
      await settle(tester);
      expect(find.text('3'), findsOneWidget);
      expect(tester.widget<IconButton>(increase).onPressed, isNull);

      await tester.tap(_size('M'));
      await settle(tester);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('quantity-value'))).data,
        '1',
      );
    });

    testWidgets('adding passes the variant details to the bag', (tester) async {
      final container = await _open(tester, _variantProduct());
      await tester.tap(_size('M'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('quantity-increase')));
      await settle(tester);
      await tester.tap(_addToBag);
      await settle(tester);
      final item = container.read(bagProvider).single;
      expect(item.quantity, 2);
      expect(item.unitPrice, 2500);
      expect(item.stockLimit, 5);
      expect(container.read(bagItemCountProvider), 2);
    });

    testWidgets('VIEW BAG opens the bag', (tester) async {
      final container = await _open(tester, _variantProduct());
      await tester.tap(_size('M'));
      await settle(tester);
      await tester.tap(_addToBag);
      await settle(tester);
      await tester.tap(find.text('VIEW BAG'));
      await settle(tester);
      expect(currentUri(container).path, '/bag');
    });

    testWidgets('products without a size have no size section', (tester) async {
      await _open(
        tester,
        testProduct(
          name: 'Watch',
          requiresColor: true,
          variants: [testVariant('One Size', 'Black')],
          colors: const [_black],
        ),
      );
      expect(find.text('SELECT SIZE'), findsNothing);
      expect(find.text('COLOR'), findsOneWidget);
      expect(find.textContaining('Add to Bag'), findsOneWidget);
    });
  });

  group('product details', () {
    testWidgets('the size guide stays plain text', (tester) async {
      await _open(tester, _variantProduct());
      expect(find.text('Size guide'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Size guide'),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('formats bold text and bullets without showing markers', (
      tester,
    ) async {
      await _open(
        tester,
        _variantProduct(
          description:
              'An elegant piece.\n\n**Highlights:**\n- Matte finish\n- Quartz',
        ),
      );
      final description = find.byKey(const ValueKey('product-description'));
      final texts = tester
          .widgetList<Text>(
            find.descendant(of: description, matching: find.byType(Text)),
          )
          .map((text) => text.textSpan?.toPlainText() ?? text.data ?? '')
          .toList();
      expect(texts, contains('Highlights:'));
      expect(texts, contains('Matte finish'));
      expect(texts.where((text) => text == '•'), hasLength(2));
      expect(texts.join(), isNot(contains('**')));
      expect(texts.join(), isNot(contains('- ')));
    });

    testWidgets('strikes the original price only when higher', (tester) async {
      await _open(tester, _variantProduct(originalPrice: 3000));
      expect(find.text('₹3,000'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('hides an original price that is not higher', (tester) async {
      await _open(tester, _variantProduct(originalPrice: 1000));
      expect(find.text('₹1,000'), findsNothing);
    });

    testWidgets('the wishlist heart toggles', (tester) async {
      await _open(tester, _variantProduct());
      expect(find.byTooltip('Add to wishlist'), findsOneWidget);
      await tester.tap(find.byTooltip('Add to wishlist'));
      await settle(tester);
      expect(find.byTooltip('Remove from wishlist'), findsOneWidget);
    });
  });

  group('back link', () {
    testWidgets('goes to the shop on a direct link', (tester) async {
      final container = await _open(tester, _variantProduct());
      await tester.tap(find.byKey(const ValueKey('product-back')));
      await settle(tester);
      expect(currentUri(container).toString(), '/shop');
    });

    testWidgets('returns to the filtered list the customer came from', (
      tester,
    ) async {
      final container = await pumpStorefront(
        tester,
        catalogue: () async => const [],
        directProduct: _variantProduct(),
        location: '/product/$testProductId',
        size: const Size(1280, 1400),
      );
      await settle(tester);
      container
          .read(storefrontNavigationMemoryProvider)
          .rememberProductOrigin('/shop?q=linen', 0);
      await tester.tap(find.byKey(const ValueKey('product-back')));
      await settle(tester);
      expect(currentUri(container).toString(), '/shop?q=linen');
    });
  });

  group('gallery', () {
    final gallery = _variantProduct(gallery: const ['a.jpg', 'b.jpg', 'c.jpg']);

    int page(WidgetTester tester) => tester
        .widget<PageView>(find.byKey(const ValueKey('product-gallery')))
        .controller!
        .page!
        .round();

    Future<void> animate(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('arrows move between images and stop at the ends', (
      tester,
    ) async {
      await _open(tester, gallery);
      final previous = find.byKey(const ValueKey('gallery-previous'));
      final next = find.byKey(const ValueKey('gallery-next'));
      expect(tester.widget<IconButton>(previous).onPressed, isNull);
      await tester.tap(next);
      await animate(tester);
      expect(page(tester), 1);
      await tester.tap(next);
      await animate(tester);
      expect(page(tester), 2);
      expect(tester.widget<IconButton>(next).onPressed, isNull);
    });

    testWidgets('thumbnails jump to an image', (tester) async {
      await _open(tester, gallery);
      await tester.tap(find.byKey(const ValueKey('gallery-thumbnail-2')));
      await animate(tester);
      expect(page(tester), 2);
    });

    testWidgets('arrow keys move between images once focused', (tester) async {
      await _open(tester, gallery);
      await tester.tap(find.byKey(const ValueKey('product-gallery')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await animate(tester);
      expect(page(tester), 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await animate(tester);
      expect(page(tester), 0);
    });

    testWidgets('a mouse can drag between images', (tester) async {
      await _open(tester, gallery);
      await tester.drag(
        find.byKey(const ValueKey('product-gallery')),
        const Offset(-500, 0),
        kind: PointerDeviceKind.mouse,
      );
      await animate(tester);
      expect(page(tester), 1);
    });

    testWidgets('phones swipe, with dots and no arrows or thumbnails', (
      tester,
    ) async {
      await _open(tester, gallery, size: const Size(390, 1400));
      expect(find.byKey(const ValueKey('gallery-next')), findsNothing);
      expect(find.byKey(const ValueKey('gallery-thumbnail-0')), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('product-gallery')),
        const Offset(-300, 0),
      );
      await animate(tester);
      expect(page(tester), 1);
    });

    testWidgets('a single image shows no gallery controls', (tester) async {
      await _open(tester, _variantProduct(gallery: const ['only.jpg']));
      expect(find.byKey(const ValueKey('gallery-next')), findsNothing);
      expect(find.byKey(const ValueKey('gallery-thumbnail-0')), findsNothing);
    });
  });

  group('layouts', () {
    testWidgets('phones get the fixed bottom Add to Bag', (tester) async {
      await _open(tester, _variantProduct(), size: const Size(390, 844));
      expect(
        find.byKey(const ValueKey('product-details-phone')),
        findsOneWidget,
      );
      expect(tester.getBottomLeft(_addToBag).dy, greaterThan(760));
    });

    testWidgets('wider screens use two columns', (tester) async {
      await _open(tester, _variantProduct(), size: const Size(1024, 1200));
      expect(
        find.byKey(const ValueKey('product-details-wide')),
        findsOneWidget,
      );
      final gallery = tester.getCenter(
        find.byKey(const ValueKey('product-gallery')),
      );
      final name = tester.getCenter(find.byKey(const ValueKey('product-name')));
      expect(gallery.dx, lessThan(name.dx));
    });

    for (final width in [360.0, 390.0, 768.0, 1024.0, 1440.0, 1920.0]) {
      testWidgets('fits at ${width.toInt()}px', (tester) async {
        await _open(
          tester,
          _variantProduct(gallery: const ['a.jpg', 'b.jpg']),
          size: Size(width, 900),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
