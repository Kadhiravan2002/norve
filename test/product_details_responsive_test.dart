import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve/features/products/product_details_screen.dart';

void main() {
  const product = Product(
    id: 'responsive-product',
    sku: 'NORVE-RESP-01',
    name: 'Considered Everyday Cotton Shirt',
    price: 1499,
    originalPrice: 1799,
    imageUrl: 'https://example.com/primary.jpg',
    galleryImageUrls: [
      'https://example.com/primary.jpg',
      'https://example.com/detail.jpg',
    ],
    category: 'Shirts',
    description: 'A considered essential with a relaxed fit and a soft, breathable hand feel.',
    sizes: ['S', 'M', 'L', 'XL'],
    colors: [
      ProductColor('Chalk', 0xFFF5F1EA),
      ProductColor('Charcoal', 0xFF24211E),
    ],
    stockQuantity: 12,
    requiresSize: true,
    requiresColor: true,
  );

  for (final width in [768.0, 1024.0, 1280.0, 1440.0]) {
    testWidgets('product details fit at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ProductDetailsScreen(product: product)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('product-details-responsive-scroll')),
        findsOneWidget,
      );
      expect(find.text(product.name), findsOneWidget);
      expect(find.text('Add to Bag  ·  ₹1,499'), findsOneWidget);
      expect(find.byKey(const ValueKey('product-gallery')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mobile retains the existing gallery and fixed bag action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ProductDetailsScreen(product: product)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('product-details-scroll')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('product-details-responsive-scroll')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('add-to-bag')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('product-gallery'))).height,
      440,
    );
    expect(tester.takeException(), isNull);
  });
}
