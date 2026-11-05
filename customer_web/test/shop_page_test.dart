import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/features/products/product.dart';

import 'support/harness.dart';

void main() {
  final catalogue = <Product>[
    testProduct(
      id: 'shirt',
      name: 'Linen Shirt',
      price: 2000,
      createdAt: DateTime(2026, 1, 2),
    ),
    testProduct(
      id: 'tee',
      name: 'Cotton Tee',
      price: 800,
      createdAt: DateTime(2026, 1, 3),
    ),
    testProduct(
      id: 'coat',
      name: 'Wool Coat',
      price: 5000,
      categoryId: 'cat-outer',
      stock: 0,
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  const desktop = Size(1280, 1600);
  const phone = Size(390, 1600);

  Future<ProviderContainer> open(
    WidgetTester tester, {
    String location = '/shop',
    Size size = desktop,
  }) async {
    final container = await pumpStorefront(
      tester,
      catalogue: () async => catalogue,
      location: location,
      size: size,
    );
    await settle(tester);
    return container;
  }

  double top(WidgetTester tester, String name) =>
      tester.getTopLeft(find.text(name)).dy;
  double left(WidgetTester tester, String name) =>
      tester.getTopLeft(find.text(name)).dx;

  Future<void> choose(
    WidgetTester tester,
    String fieldKeyPrefix,
    String option,
  ) async {
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key as ValueKey<String>).value.startsWith(fieldKeyPrefix),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(option).last);
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('shop-open-filters')));
    await settle(tester);
  }

  testWidgets('counts products, with the correct singular', (tester) async {
    await open(tester);
    expect(find.text('3 considered essentials'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('shop-search')), 'wool');
    await settle(tester);
    expect(find.text('1 considered essential'), findsOneWidget);
  });

  testWidgets('search filters immediately and updates the URL after a pause', (
    tester,
  ) async {
    final container = await open(tester);
    await tester.enterText(find.byKey(const ValueKey('shop-search')), 'linen');
    await tester.pump();
    expect(find.text('Linen Shirt'), findsOneWidget);
    expect(find.text('Cotton Tee'), findsNothing);
    expect(currentUri(container).queryParameters['q'], isNull);

    await settle(tester);
    expect(currentUri(container).queryParameters['q'], 'linen');
  });

  testWidgets('opening a filtered URL restores the whole view', (tester) async {
    await open(
      tester,
      location: '/shop?q=coat&categoryId=cat-outer&stock=out&sort=price-desc',
    );
    expect(find.text('Wool Coat'), findsOneWidget);
    expect(find.text('Linen Shirt'), findsNothing);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('shop-search')),
    );
    expect(field.controller!.text, 'coat');
    expect(find.text('Outerwear'), findsOneWidget);
    expect(find.text('Out of stock'), findsOneWidget);
    expect(find.text('Price: high to low'), findsOneWidget);
  });

  testWidgets('navigating to a new URL updates the search field', (
    tester,
  ) async {
    final container = await open(tester, location: '/shop?q=coat');
    routerOf(container).go('/shop?q=tee');
    await settle(tester);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('shop-search')),
    );
    expect(field.controller!.text, 'tee');
    expect(find.text('Cotton Tee'), findsOneWidget);
    expect(find.text('Wool Coat'), findsNothing);
  });

  testWidgets('the category filter updates products and URL', (tester) async {
    final container = await open(tester);
    await choose(tester, 'shop-category-filter', 'Outerwear');
    expect(currentUri(container).queryParameters['categoryId'], 'cat-outer');
    expect(find.text('Wool Coat'), findsOneWidget);
    expect(find.text('Linen Shirt'), findsNothing);
  });

  testWidgets('the availability filter updates products and URL', (
    tester,
  ) async {
    final container = await open(tester);
    await choose(tester, 'shop-availability-filter', 'Out of stock');
    expect(currentUri(container).queryParameters['stock'], 'out');
    expect(find.text('Wool Coat'), findsOneWidget);
    expect(find.text('Cotton Tee'), findsNothing);
    expect(find.text('SOLD OUT'), findsOneWidget);
  });

  testWidgets('sorting reorders products and updates the URL', (tester) async {
    final container = await open(tester);
    await choose(tester, 'shop-sort-filter', 'Price: high to low');
    expect(currentUri(container).queryParameters['sort'], 'price-desc');
    expect(left(tester, 'Wool Coat'), lessThan(left(tester, 'Linen Shirt')));
    expect(top(tester, 'Wool Coat'), top(tester, 'Linen Shirt'));
    expect(left(tester, 'Linen Shirt'), lessThan(left(tester, 'Cotton Tee')));
  });

  testWidgets('Clear filters resets everything', (tester) async {
    final container = await open(
      tester,
      location: '/shop?q=coat&categoryId=cat-outer&stock=out&sort=price-asc',
    );
    await tester.tap(find.byKey(const ValueKey('shop-clear-filters')));
    await settle(tester);
    expect(currentUri(container).toString(), '/shop');
    expect(find.text('3 considered essentials'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('shop-search')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('no matches gets its own message', (tester) async {
    await open(tester, location: '/shop?q=nothing-like-this');
    expect(
      find.text('No pieces match your search and filters.'),
      findsOneWidget,
    );
    expect(find.text('New pieces are on their way.'), findsNothing);
  });

  testWidgets('invalid URL values fall back to the defaults', (tester) async {
    await open(tester, location: '/shop?sort=bad&stock=bad&categoryId=bad');
    expect(find.text('Newest'), findsOneWidget);
    expect(find.text('Any availability'), findsOneWidget);
    expect(find.text('All categories'), findsOneWidget);
    expect(find.text('3 considered essentials'), findsOneWidget);
    expect(find.text('Linen Shirt'), findsOneWidget);
  });

  testWidgets('the header search icon focuses the search field', (
    tester,
  ) async {
    await open(tester, location: '/');
    await tester.tap(find.byKey(const ValueKey('storefront-search')));
    await settle(tester);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('shop-search')),
    );
    expect(field.focusNode!.hasFocus, isTrue);
  });

  group('phone and tablet filters', () {
    testWidgets('use a sheet instead of the desktop bar', (tester) async {
      await open(tester, size: phone);
      expect(find.byKey(const ValueKey('shop-open-filters')), findsOneWidget);
      expect(find.text('Any availability'), findsNothing);
      await openSheet(tester);
      expect(find.byKey(const ValueKey('shop-filter-sheet')), findsOneWidget);
      expect(find.text('Any availability'), findsOneWidget);
    });

    testWidgets('changes apply only after Show results', (tester) async {
      final container = await open(tester, size: phone);
      await openSheet(tester);
      await choose(tester, 'shop-availability-filter', 'Out of stock');
      expect(currentUri(container).queryParameters['stock'], isNull);

      await tester.tap(find.byKey(const ValueKey('shop-sheet-apply')));
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(currentUri(container).queryParameters['stock'], 'out');
      expect(find.text('Filters (1)'), findsOneWidget);
      expect(find.text('Wool Coat'), findsOneWidget);
      expect(find.text('Cotton Tee'), findsNothing);
    });

    testWidgets('dismissing the sheet changes nothing', (tester) async {
      final container = await open(tester, size: phone);
      await openSheet(tester);
      await choose(tester, 'shop-availability-filter', 'Out of stock');
      await tester.tapAt(const Offset(195, 20));
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(currentUri(container).toString(), '/shop');
      expect(find.text('Cotton Tee'), findsOneWidget);
    });

    testWidgets('the sheet keeps a search in progress', (tester) async {
      final container = await open(tester, size: phone, location: '/shop?q=e');
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('shop-sheet-clear')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('shop-sheet-apply')));
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(currentUri(container).queryParameters['q'], 'e');
    });
  });

  for (final width in [360.0, 390.0, 768.0, 1024.0, 1440.0, 1920.0]) {
    testWidgets('fits at ${width.toInt()}px', (tester) async {
      await open(tester, size: Size(width, 900));
      expect(find.byKey(const ValueKey('shop-search')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
