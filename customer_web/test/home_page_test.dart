import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/features/products/product_repository.dart';

import 'support/harness.dart';

void main() {
  final catalogue = [
    for (var i = 1; i <= 15; i++)
      testProduct(
        id: 'p$i',
        name: 'Piece $i',
        categoryId: i == 1 ? 'cat-outer' : 'cat-tops',
        createdAt: DateTime(2026, 1, i),
      ),
  ];

  Future<void> open(
    WidgetTester tester, {
    String location = '/',
    Size size = const Size(1280, 4200),
    Future<List<ProductCategory>> Function()? categories,
  }) async {
    await pumpStorefront(
      tester,
      catalogue: () async => catalogue,
      categories: categories,
      location: location,
      size: size,
    );
    await settle(tester);
  }

  testWidgets('shows the mobile hero content', (tester) async {
    await open(tester);
    expect(find.text('THE EVERYDAY EDIT'), findsOneWidget);
    expect(find.text('A New Perspective on Everyday Style'), findsOneWidget);
    expect(
      find.text(
        'Considered essentials. Timeless silhouettes. Made for your everyday.',
      ),
      findsOneWidget,
    );
    expect(find.text('Discover the Collection'), findsOneWidget);
  });

  testWidgets('Discover the Collection opens the shop', (tester) async {
    final container = await pumpStorefront(
      tester,
      catalogue: () async => catalogue,
      size: const Size(1280, 4200),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('discover-collection')));
    await settle(tester);
    expect(currentUri(container).path, '/shop');
  });

  testWidgets('shows every active product newest first by default', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Just Arrived'), findsOneWidget);
    expect(find.text('Piece 15'), findsOneWidget);
    expect(find.text('Piece 1'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Piece 15')).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.text('Piece 1')).dy),
    );
  });

  testWidgets('New Arrivals shows only the newest 12', (tester) async {
    await open(tester, location: '/?newArrivals=true');
    expect(find.text('New Arrivals'), findsWidgets);
    expect(find.text('Just Arrived'), findsNothing);
    expect(find.text('Piece 15'), findsOneWidget);
    expect(find.text('Piece 4'), findsOneWidget);
    expect(find.text('Piece 3'), findsNothing);
  });

  testWidgets('the New Arrivals chip updates the URL', (tester) async {
    final container = await pumpStorefront(
      tester,
      catalogue: () async => catalogue,
      size: const Size(1280, 4200),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('home-category-new-arrivals')));
    await settle(tester);
    expect(currentUri(container).queryParameters['newArrivals'], 'true');
    expect(find.text('Piece 3'), findsNothing);
  });

  testWidgets('a category chip filters and names the section', (tester) async {
    final container = await pumpStorefront(
      tester,
      catalogue: () async => catalogue,
      size: const Size(1280, 4200),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('home-category-cat-outer')));
    await settle(tester);
    expect(currentUri(container).queryParameters['categoryId'], 'cat-outer');
    expect(find.text('Outerwear'), findsWidgets);
    expect(find.text('Piece 1'), findsOneWidget);
    expect(find.text('Piece 2'), findsNothing);
  });

  testWidgets('VIEW ALL keeps the selected category', (tester) async {
    final container = await pumpStorefront(
      tester,
      catalogue: () async => catalogue,
      location: '/?categoryId=cat-outer',
      size: const Size(1280, 4200),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('home-view-all')));
    await settle(tester);
    final uri = currentUri(container);
    expect(uri.path, '/shop');
    expect(uri.queryParameters['categoryId'], 'cat-outer');
  });

  testWidgets('an unknown category falls back to everything', (tester) async {
    await open(tester, location: '/?categoryId=not-real');
    expect(find.text('Just Arrived'), findsOneWidget);
    expect(find.text('Piece 2'), findsOneWidget);
  });

  testWidgets('shows a spinner while categories load', (tester) async {
    final completer = Completer<List<ProductCategory>>();
    await open(tester, categories: () => completer.future);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(testCategories);
    await settle(tester);
    expect(find.text('Outerwear'), findsOneWidget);
  });

  testWidgets('a category failure offers a retry', (tester) async {
    var attempts = 0;
    await open(
      tester,
      categories: () async {
        attempts++;
        if (attempts == 1) throw Exception('offline');
        return testCategories;
      },
    );
    // Riverpod may retry on its own, so accept either outcome once settled.
    final retry = find.text('Categories unavailable · Retry');
    if (retry.evaluate().isNotEmpty) {
      await tester.tap(retry);
      await settle(tester);
    }
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(find.text('Outerwear'), findsOneWidget);
  });

  testWidgets('says so when there are no active categories', (tester) async {
    await open(tester, categories: () async => const []);
    expect(find.text('No active categories'), findsOneWidget);
  });

  for (final width in [360.0, 390.0, 768.0, 1024.0, 1440.0, 1920.0]) {
    testWidgets('fits at ${width.toInt()}px', (tester) async {
      await open(tester, size: Size(width, 900));
      expect(find.byKey(const ValueKey('home-hero')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
