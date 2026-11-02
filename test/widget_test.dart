import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/app/norve_app.dart';
import 'package:norve/core/supabase/supabase_config.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/features/bag/bag_provider.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve/features/products/product_catalog_provider.dart';
import 'package:norve/features/products/product_details_screen.dart';
import 'package:norve/features/products/product_repository.dart';

class _MemoryProductRepository extends ProductRepository {
  _MemoryProductRepository() : super(null);
  final Map<String, Product> saved = {};
  bool failFetch = false;
  Object? fetchError;

  @override
  Future<List<Product>> fetchProducts() async {
    if (failFetch) throw fetchError ?? Exception('offline');
    return saved.values.toList();
  }

  @override
  Future<Product> create(Product product) async {
    saved[product.id] = product;
    return product;
  }

  @override
  Future<Product> update(Product product) async {
    saved[product.id] = product;
    return product;
  }

  @override
  Future<void> delete(String productId) async {
    saved.remove(productId);
  }
}

void main() {
  Finder homeScrollable() => find
      .descendant(
        of: find.byKey(const ValueKey('home-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> scrollToCottonTee(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Essential Cotton Tee'),
      200,
      scrollable: homeScrollable(),
    );
    await tester.drag(homeScrollable(), const Offset(0, -80));
    await tester.pumpAndSettle();
  }

  Future<void> openApp(
    WidgetTester tester, [
    List<dynamic> overrides = const [],
  ]) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productCategoriesProvider.overrideWith(
            (ref) => Future.value(const [
              ProductCategory(
                id: 't-shirts',
                name: 'T-shirts',
                slug: 't-shirts',
                description: 'T-shirts category',
              ),
              ProductCategory(
                id: 'shirts',
                name: 'Shirts',
                slug: 'shirts',
                description: 'Shirts category',
              ),
            ]),
          ),
          ...overrides.cast(),
        ],
        child: const NorveApp(),
      ),
    );
    await tester.pumpAndSettle();
    if (find.byTooltip('Back').evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
    }
    if (find.byIcon(Icons.home_outlined).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('home screen shows brand, hero, categories and mock products', (
    tester,
  ) async {
    await openApp(tester);
    expect(find.text('NORVÉ'), findsOneWidget);
    expect(find.text('A New Perspective on Everyday Style'), findsOneWidget);
    expect(find.text('Discover the Collection'), findsOneWidget);
    expect(find.text('New Arrivals'), findsOneWidget);
    await scrollToCottonTee(tester);
    expect(find.text('₹799'), findsOneWidget);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('customer home and shop hide the development catalogue notice', (
    tester,
  ) async {
    await openApp(tester);
    const notice =
        'Development catalogue · not live inventory or business data.';
    expect(find.text(notice), findsNothing);
    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
    expect(find.text(notice), findsNothing);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Discover the Collection opens the unfiltered Shop', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(find.byKey(const ValueKey('discover-collection')));
    await tester.pumpAndSettle();

    expect(find.text('Shop'), findsAtLeastNWidgets(1));
    expect(find.text('6 considered essentials'), findsOneWidget);
    expect(find.text('All categories'), findsOneWidget);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('wishlist button toggles its saved state', (tester) async {
    await openApp(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('wishlist-cotton-tee')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    final button = find.byKey(const ValueKey('wishlist-cotton-tee'));
    expect(tester.widget<IconButton>(button).tooltip, 'Add to wishlist');
    await tester.tap(button);
    await tester.pump();
    expect(tester.widget<IconButton>(button).tooltip, 'Remove from wishlist');
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('product details retain size selection and bag interaction', (
    tester,
  ) async {
    await openApp(tester);
    await scrollToCottonTee(tester);
    await tester.tap(find.text('Essential Cotton Tee'));
    await tester.pumpAndSettle();
    expect(find.text('T-SHIRTS'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-to-bag')));
    await tester.pump();
    expect(find.text('Please select a size first.'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('product-details-scroll')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('M'));
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('bottom navigation opens shop and account with setup state', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
    expect(find.text('6 considered essentials'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('Admin Sign In'), findsNothing);
    expect(
      find.text('Account services are unavailable right now.'),
      findsOneWidget,
    );
    expect(find.text('DEMO ACCESS'), findsNothing);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('shop search, category filter and clear filters work together', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('shop-search')), 'linen');
    await tester.pumpAndSettle();
    expect(find.text('Relaxed Linen Shirt'), findsOneWidget);
    expect(find.text('Essential Cotton Tee'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('shop-category-filter-__all_categories__')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('T-shirts').last);
    await tester.pumpAndSettle();
    expect(
      find.text('No pieces match your search and filters.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('shop-clear-filters')));
    await tester.pumpAndSettle();
    expect(find.text('6 considered essentials'), findsOneWidget);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('variant stock and price override control customer selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final product = Product(
      id: 'variant-test',
      sku: 'NORVE-001',
      name: 'Variant test garment',
      price: 999,
      imageUrl: '',
      category: 'T-shirts',
      description: 'Variant selection fixture',
      sizes: const ['S', 'M'],
      colors: const [ProductColor('Chalk', 0xFFF5F1EA)],
      stockQuantity: 2,
      variants: const [
        ProductVariant(
          id: 'variant-s',
          sku: 'NORVE-001-S',
          size: 'S',
          colorName: 'Chalk',
          colorValue: 0xFFF5F1EA,
          stockQuantity: 0,
        ),
        ProductVariant(
          id: 'variant-m',
          sku: 'NORVE-001-M',
          size: 'M',
          colorName: 'Chalk',
          colorValue: 0xFFF5F1EA,
          priceOverride: 799,
          stockQuantity: 2,
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: ProductDetailsScreen(product: product)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('S'));
    await tester.tap(find.text('S'));
    await tester.pumpAndSettle();
    expect(find.text('Please select a size to continue.'), findsOneWidget);
    await tester.tap(find.text('M'));
    await tester.pumpAndSettle();
    final addButton = find.byKey(const ValueKey('add-to-bag'));
    expect(tester.widget<FilledButton>(addButton).onPressed, isNotNull);
    expect(find.text('Add to Bag  ·  ₹799'), findsOneWidget);
    await tester.tap(addButton);
    await tester.pump();
    final item = container.read(bagProvider).single;
    expect(item.size, 'M');
    expect(item.color, 'Chalk');
    expect(item.unitPrice, 799);
    expect(item.stockLimit, 2);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('selected product variant adds to bag and totals update', (
    tester,
  ) async {
    await openApp(tester);
    await scrollToCottonTee(tester);
    await tester.tap(find.text('Essential Cotton Tee'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('product-details-scroll')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('M'));
    await tester.drag(
      find.byKey(const ValueKey('product-details-scroll')),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.tap(find.byKey(const ValueKey('add-to-bag')));
    await tester.pump();
    expect(
      find.text('Essential Cotton Tee added to your bag.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.shopping_bag_outlined));
    await tester.pumpAndSettle();
    expect(find.text('₹1,598'), findsNWidgets(2));
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('wishlist can be emptied and return to shopping', (tester) async {
    await openApp(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('wishlist-cotton-tee')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('wishlist-cotton-tee')));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.favorite_border).last);
    await tester.pumpAndSettle();
    expect(find.text('Essential Cotton Tee'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wishlist-cotton-tee')));
    await tester.pumpAndSettle();
    expect(find.text('A little room for something lovely.'), findsOneWidget);
    await tester.tap(find.text('Continue Shopping'));
    await tester.pumpAndSettle();
    expect(find.text('A New Perspective on Everyday Style'), findsOneWidget);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  test('bag combines identical variants and calculates INR totals', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final product = products.first;
    final bag = container.read(bagProvider.notifier);
    bag.add(product, size: 'M', color: 'Chalk', quantity: 2);
    bag.add(product, size: 'M', color: 'Chalk');
    bag.add(product, size: 'L', color: 'Chalk');
    final items = container.read(bagProvider);
    expect(items, hasLength(2));
    expect(items.first.quantity, 3);
    expect(items.first.lineTotal, 2397);
    expect(container.read(bagSubtotalProvider), 3196);
    expect(container.read(bagItemCountProvider), 4);
    expect(formatInr(1499), '₹1,499');
  });

  test('configuration accepts only project URL and publishable key', () {
    expect(
      const SupabaseConfig(url: '', publishableKey: '').isConfigured,
      isFalse,
    );
    expect(
      const SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'sb_publishable_test',
      ).isConfigured,
      isTrue,
    );
    expect(
      const SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'service_role_secret',
      ).isConfigured,
      isFalse,
    );
    expect(
      const SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'sb_publishable_test',
      ).configurationMessage,
      'Supabase is configured.',
    );
  });

  test(
    'Supabase product mapping reconstructs catalogue variants and inventory',
    () {
      final product = Product.fromSupabaseRow({
        'id': 'p-1',
        'name': 'Linen Shirt',
        'description': 'Relaxed fit',
        'price_inr': '1499.00',
        'original_price_inr': null,
        'image_url': 'https://example.com/shirt.jpg',
        'is_active': true,
        'categories': {'name': 'Shirts'},
        'product_variants': [
          {
            'size': 'S',
            'color_name': 'Natural',
            'color_hex': '#D9CDBB',
            'stock_quantity': 4,
          },
          {
            'size': 'M',
            'color_name': 'Natural',
            'color_hex': '#D9CDBB',
            'stock_quantity': 3,
          },
        ],
      });
      expect(product.price, 1499);
      expect(product.category, 'Shirts');
      expect(product.sizes, ['S', 'M']);
      expect(product.colors.single.name, 'Natural');
      expect(product.stockQuantity, 7);
      expect(product.isActive, isTrue);
    },
  );

  test('shared catalogue updates only after repository success', () async {
    final repository = _MemoryProductRepository();
    final container = ProviderContainer(
      overrides: [productRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(productCatalogProvider.notifier);
    final first = container.read(productCatalogProvider).first;
    await controller.save(
      first.copyWith(price: 999, stockQuantity: 7, isActive: false),
      create: false,
    );
    expect(container.read(productCatalogProvider).first.price, 999);
    expect(container.read(productCatalogProvider).first.stockQuantity, 7);
    expect(container.read(productCatalogProvider).first.isActive, isFalse);
    final added = first.copyWith(id: 'added', name: 'Added Product');
    await controller.save(added, create: true);
    expect(container.read(productCatalogProvider).last.id, 'added');
    await controller.delete('added');
    expect(
      container.read(productCatalogProvider).any((item) => item.id == 'added'),
      isFalse,
    );
  });

  test('catalogue reports fetch errors without claiming live data', () async {
    final repository = _MemoryProductRepository()..failFetch = true;
    final container = ProviderContainer(
      overrides: [productRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container
        .read(catalogLoadStateProvider.notifier)
        .set(const CatalogLoadState(CatalogPhase.loading));
    expect(
      container.read(catalogLoadStateProvider).phase,
      CatalogPhase.loading,
    );
    await container.read(productCatalogProvider.notifier).refresh();
    expect(container.read(catalogLoadStateProvider).phase, CatalogPhase.error);
  });

  test('catalogue identifies an unapplied schema migration', () async {
    final repository = _MemoryProductRepository()
      ..failFetch = true
      ..fetchError = Exception(
        'PostgrestException(code: PGRST200, missing relation)',
      );
    final container = ProviderContainer(
      overrides: [productRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(productCatalogProvider.notifier).refresh();

    expect(container.read(catalogLoadStateProvider).phase, CatalogPhase.error);
    expect(
      container.read(catalogLoadStateProvider).message,
      contains('schema is out of date'),
    );
  });
}
