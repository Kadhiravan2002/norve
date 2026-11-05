import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/core/auth/auth_providers.dart';
import 'package:norve/core/auth/auth_repository.dart';
import 'package:norve/core/supabase/supabase_config.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve/features/products/product_catalog_provider.dart';
import 'package:norve/features/products/product_repository.dart';
import 'package:norve_customer_web/app/router.dart';
import 'package:norve_customer_web/app/storefront_app.dart';
import 'package:norve_customer_web/catalog/storefront_catalog_repository.dart';
import 'package:norve_customer_web/pages/catalogue_page.dart';
import 'package:norve_customer_web/pages/storefront_unavailable_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _productId = '11111111-1111-4111-8111-111111111111';

Product _product({String id = _productId, String name = 'Live Linen Shirt'}) =>
    Product(
      id: id,
      name: name,
      price: 2499,
      // Empty URL resolves to the image fallback without any network request.
      imageUrl: '',
      category: 'Shirts',
      description: 'From Supabase.',
      sizes: const [],
      colors: const [],
    );

class _FakeProductRepository extends ProductRepository {
  _FakeProductRepository(this.fetch) : super(null);

  final Future<List<Product>> Function() fetch;

  @override
  Future<List<Product>> fetchProducts() => fetch();
}

class _FakeCatalogRepository extends StorefrontCatalogRepository {
  const _FakeCatalogRepository(this.product) : super(null);

  final Product? product;

  @override
  Future<Product?> fetchById(String id) async => product;
}

class _GuestAuthRepository implements AuthRepository {
  @override
  AuthSession? get currentSession => null;
  @override
  Stream<AuthSession?> watchSession() => Stream.value(null);
  @override
  Stream<AuthChangeEvent?> watchAuthEvents() => const Stream.empty();
  @override
  Future<AuthActionResult> signIn({
    required String email,
    required String password,
  }) => throw UnimplementedError();
  @override
  Future<AuthActionResult> signUp({
    required String email,
    required String password,
  }) => throw UnimplementedError();
  @override
  Future<void> signOut() async {}
  @override
  Future<void> sendPasswordReset(String email, {String? redirectTo}) async {}
  @override
  Future<void> updatePassword(String password) async {}
}

SupabaseClient _client() => SupabaseClient(
  'https://example.supabase.co',
  'sb_publishable_test',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required Future<List<Product>> Function() catalogue,
  Product? directProduct,
  String location = '/',
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      supabaseConfigProvider.overrideWithValue(
        const SupabaseConfig(
          url: 'https://example.supabase.co',
          publishableKey: 'sb_publishable_test',
        ),
      ),
      supabaseClientProvider.overrideWithValue(_client()),
      authRepositoryProvider.overrideWithValue(_GuestAuthRepository()),
      productRepositoryProvider.overrideWithValue(
        _FakeProductRepository(catalogue),
      ),
      storefrontCatalogRepositoryProvider.overrideWithValue(
        _FakeCatalogRepository(directProduct),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(storefrontRouterProvider).go(location);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const StorefrontApp(),
    ),
  );
  return container;
}

/// Lets async providers settle without waiting on endless spinners.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('catalogue states', () {
    testWidgets('shows loading, then live repository products', (tester) async {
      final completer = Completer<List<Product>>();
      await _pump(tester, catalogue: () => completer.future);
      await _settle(tester);
      expect(find.byKey(const ValueKey('catalogue-loading')), findsOneWidget);
      expect(find.text('Live Linen Shirt'), findsNothing);

      completer.complete([_product()]);
      await _settle(tester);
      expect(find.byKey(const ValueKey('catalogue-loading')), findsNothing);
      expect(find.text('Live Linen Shirt'), findsOneWidget);
    });

    testWidgets('shows a customer-friendly error and recovers on retry', (
      tester,
    ) async {
      var attempts = 0;
      await _pump(
        tester,
        catalogue: () async {
          attempts++;
          if (attempts == 1) throw Exception('42501 permission denied');
          return [_product()];
        },
      );
      await _settle(tester);
      expect(find.byKey(const ValueKey('catalogue-error')), findsOneWidget);
      expect(find.textContaining('Administrator'), findsNothing);
      expect(find.textContaining('42501'), findsNothing);

      await tester.tap(find.text('Try again'));
      await _settle(tester);
      expect(attempts, 2);
      expect(find.text('Live Linen Shirt'), findsOneWidget);
    });

    testWidgets('shows the empty state when Supabase has no products', (
      tester,
    ) async {
      await _pump(tester, catalogue: () async => const []);
      await _settle(tester);
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

    test('keeps loaded products visible through a refresh or failed refresh', () {
      for (final phase in [CatalogPhase.loading, CatalogPhase.error]) {
        expect(
          resolveCatalogueView(CatalogLoadState(phase), [_product()]),
          CatalogueView.products,
        );
      }
    });
  });

  group('routing in the app', () {
    testWidgets('a guest opening checkout is sent to sign-in', (tester) async {
      final container = await _pump(
        tester,
        catalogue: () async => [_product()],
        location: '/checkout',
      );
      await _settle(tester);
      final uri = container
          .read(storefrontRouterProvider)
          .routeInformationProvider
          .value
          .uri;
      expect(uri.path, '/account');
      expect(uri.queryParameters['from'], '/checkout');
    });

    testWidgets('a guest opening a product stays on it', (tester) async {
      await _pump(
        tester,
        catalogue: () async => const [],
        directProduct: _product(name: 'Direct Link Coat'),
        location: '/product/$_productId',
      );
      await _settle(tester);
      expect(find.text('Direct Link Coat'), findsWidgets);
    });

    testWidgets('a missing product shows the unavailable message', (
      tester,
    ) async {
      await _pump(
        tester,
        catalogue: () async => const [],
        location: '/product/$_productId',
      );
      await _settle(tester);
      expect(find.text('Product unavailable'), findsOneWidget);
      await tester.tap(find.text('Continue Shopping'));
      await _settle(tester);
      expect(find.text('Shop'), findsWidgets);
    });

    testWidgets('an unknown URL shows the branded not-found page', (
      tester,
    ) async {
      await _pump(
        tester,
        catalogue: () async => const [],
        location: '/no-such-page',
      );
      await _settle(tester);
      expect(
        find.byKey(const ValueKey('storefront-not-found')),
        findsOneWidget,
      );
      expect(find.text('This page could not be found'), findsOneWidget);
    });
  });

  group('responsive shell', () {
    for (final width in [360.0, 390.0, 768.0, 1024.0, 1440.0, 1920.0]) {
      testWidgets('header and catalogue fit at ${width.toInt()}px', (
        tester,
      ) async {
        await _pump(
          tester,
          catalogue: () async => [
            for (var i = 0; i < 6; i++)
              _product(id: 'product-$i', name: 'Live Piece $i'),
          ],
          size: Size(width, 900),
        );
        await _settle(tester);
        // A layout overflow would fail the test through the framework.
        expect(find.byKey(const ValueKey('storefront-header')), findsOneWidget);
        expect(find.text('Live Piece 0'), findsOneWidget);
        expect(tester.takeException(), isNull);

        final hasMenu = width < 1024;
        expect(
          find.byKey(const ValueKey('storefront-menu')),
          hasMenu ? findsOneWidget : findsNothing,
        );
        expect(find.byTooltip('Wishlist'), width < 1024 ? findsNothing : findsOneWidget);
      });
    }

    for (final width in [360.0, 1440.0]) {
      testWidgets(
        'footer spans the page and sits at the bottom at ${width.toInt()}px',
        (tester) async {
          await _pump(
            tester,
            catalogue: () async => const [],
            size: Size(width, 1400),
          );
          await _settle(tester);
          final footer = find.byKey(const ValueKey('storefront-footer'));
          expect(footer, findsOneWidget);
          expect(tester.getSize(footer).width, width);
          // On a short page the footer keeps its own height at the bottom.
          expect(tester.getSize(footer).height, lessThan(500));
          expect(tester.getBottomLeft(footer).dy, 1400);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('phone menu lists all five destinations', (tester) async {
      await _pump(
        tester,
        catalogue: () async => const [],
        size: const Size(390, 844),
      );
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('storefront-menu')));
      await tester.pump(const Duration(milliseconds: 400));
      final drawer = find.byKey(const ValueKey('storefront-drawer'));
      for (final label in ['Home', 'Shop', 'Wishlist', 'Bag', 'Account']) {
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
