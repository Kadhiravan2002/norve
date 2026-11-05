import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve/features/products/product_catalog_provider.dart';
import 'package:norve_customer_web/pages/storefront_unavailable_app.dart';
import 'package:norve_customer_web/widgets/catalogue_section.dart';

import 'support/harness.dart';

void main() {
  group('catalogue states', () {
    testWidgets('shows loading, then live repository products', (tester) async {
      final completer = Completer<List<Product>>();
      await pumpStorefront(
        tester,
        catalogue: () => completer.future,
        location: '/shop',
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('catalogue-loading')), findsOneWidget);
      expect(find.text('Live Linen Shirt'), findsNothing);

      completer.complete([testProduct()]);
      await settle(tester);
      expect(find.byKey(const ValueKey('catalogue-loading')), findsNothing);
      expect(find.text('Live Linen Shirt'), findsOneWidget);
    });

    testWidgets('shows a customer-friendly error and recovers on retry', (
      tester,
    ) async {
      var attempts = 0;
      await pumpStorefront(
        tester,
        catalogue: () async {
          attempts++;
          if (attempts == 1) throw Exception('42501 permission denied');
          return [testProduct()];
        },
        location: '/shop',
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('catalogue-error')), findsOneWidget);
      expect(find.textContaining('Administrator'), findsNothing);
      expect(find.textContaining('42501'), findsNothing);

      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(attempts, 2);
      expect(find.text('Live Linen Shirt'), findsOneWidget);
    });

    testWidgets('shows the empty state when Supabase has no products', (
      tester,
    ) async {
      await pumpStorefront(
        tester,
        catalogue: () async => const [],
        location: '/shop',
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('catalogue-empty')), findsOneWidget);
      expect(find.text('New pieces are on their way.'), findsOneWidget);
    });

    test('never shows fixture products, even if the list holds them', () {
      expect(
        resolveCatalogueView(
          const CatalogLoadState(CatalogPhase.development),
          products,
        ),
        CatalogueView.error,
      );
    });

    test(
      'keeps loaded products visible through a refresh or failed refresh',
      () {
        for (final phase in [CatalogPhase.loading, CatalogPhase.error]) {
          expect(
            resolveCatalogueView(CatalogLoadState(phase), [testProduct()]),
            CatalogueView.products,
          );
        }
      },
    );
  });

  group('routing in the app', () {
    testWidgets('a guest opening checkout is sent to sign-in', (tester) async {
      final container = await pumpStorefront(
        tester,
        catalogue: () async => [testProduct()],
        location: '/checkout',
      );
      await settle(tester);
      final uri = currentUri(container);
      expect(uri.path, '/login');
      expect(uri.queryParameters['from'], '/checkout');
    });

    testWidgets('an unknown URL shows the branded not-found page', (
      tester,
    ) async {
      await pumpStorefront(
        tester,
        catalogue: () async => const [],
        location: '/no-such-page',
      );
      await settle(tester);
      expect(
        find.byKey(const ValueKey('storefront-not-found')),
        findsOneWidget,
      );
      expect(find.text('This page could not be found'), findsOneWidget);
    });
  });

  group('responsive shell', () {
    for (final width in [360.0, 390.0, 768.0, 1024.0, 1440.0, 1920.0]) {
      testWidgets('header fits at ${width.toInt()}px', (tester) async {
        await pumpStorefront(
          tester,
          catalogue: () async => [testProduct()],
          location: '/shop',
          size: Size(width, 900),
        );
        await settle(tester);
        expect(find.byKey(const ValueKey('storefront-header')), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('storefront-menu')),
          width < 1024 ? findsOneWidget : findsNothing,
        );
        expect(
          find.byTooltip('Wishlist'),
          width < 1024 ? findsNothing : findsOneWidget,
        );
        expect(find.byKey(const ValueKey('storefront-search')), findsOneWidget);
      });
    }

    for (final width in [360.0, 1440.0]) {
      testWidgets(
        'footer spans the page and sits at the bottom at ${width.toInt()}px',
        (tester) async {
          await pumpStorefront(
            tester,
            catalogue: () async => const [],
            location: '/shop',
            size: Size(width, 1400),
          );
          await settle(tester);
          final footer = find.byKey(const ValueKey('storefront-footer'));
          expect(footer, findsOneWidget);
          expect(tester.getSize(footer).width, width);
          // On a short page the footer keeps its own height at the bottom.
          expect(tester.getSize(footer).height, lessThan(520));
          expect(tester.getBottomLeft(footer).dy, 1400);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('header controls are available to screen readers', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpStorefront(
        tester,
        catalogue: () async => [testProduct()],
        location: '/shop',
        size: const Size(1280, 900),
      );
      await settle(tester);
      expect(find.semantics.byLabel('NORVÉ home'), findsOne);
      // Icon buttons expose their name as a tooltip, not a label.
      for (final tooltip in ['Search', 'Wishlist', 'Shopping bag']) {
        expect(
          find.semantics.byPredicate(
            (node) => node.getSemanticsData().tooltip == tooltip,
          ),
          findsOne,
          reason: tooltip,
        );
      }
      // The page content stays available alongside the header.
      expect(find.semantics.byLabel(RegExp('Live Linen Shirt')), findsAny);
      semantics.dispose();
    });

    testWidgets('phone menu lists every destination', (tester) async {
      await pumpStorefront(
        tester,
        catalogue: () async => const [],
        size: const Size(390, 844),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('storefront-menu')));
      await tester.pump(const Duration(milliseconds: 400));
      final drawer = find.byKey(const ValueKey('storefront-drawer'));
      for (final label in [
        'Home',
        'Shop',
        'New Arrivals',
        'Wishlist',
        'Bag',
        'Account',
      ]) {
        expect(
          find.descendant(of: drawer, matching: find.text(label)),
          findsOneWidget,
        );
      }
    });
  });

  testWidgets('an unconfigured build shows no products', (tester) async {
    await tester.pumpWidget(const StorefrontUnavailableApp());
    expect(find.text('NORVÉ is temporarily unavailable'), findsOneWidget);
    for (final fixture in products) {
      expect(find.text(fixture.name), findsNothing);
    }
  });
}
