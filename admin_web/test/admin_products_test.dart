import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/admin/admin_products_screen.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve/features/products/product_catalog_provider.dart';
import 'package:norve/features/products/product_repository.dart';

class _FakeProductCatalogController extends ProductCatalogController {
  _FakeProductCatalogController(this._initial);
  final List<Product> _initial;

  @override
  List<Product> build() => _initial;

  @override
  Future<void> delete(String productId) async {
    state = state.where((p) => p.id != productId).toList();
  }
}

class _FakeCatalogLoadController extends CatalogLoadController {
  @override
  CatalogLoadState build() => const CatalogLoadState(CatalogPhase.live);
}

void main() {
  final testProducts = [
    Product(
      id: 'p-1',
      sku: 'NOR-OFC-01',
      name: 'Oxford Cotton Shirt',
      price: 2499,
      originalPrice: 3499,
      imageUrl: 'https://example.com/shirt.jpg',
      category: 'Shirts',
      description: 'Luxury cotton shirt',
      stockQuantity: 4, // Low stock (<= 5)
      isActive: true,
      sizes: const ['M', 'L'],
      colors: const [
        ProductColor('White', 0xFFFFFFFF),
        ProductColor('Charcoal', 0xFF24211E),
      ],
    ),
    Product(
      id: 'p-2',
      sku: 'NOR-CSH-02',
      name: 'Cashmere Knit Cardigan',
      price: 5999,
      imageUrl: 'https://example.com/knit.jpg',
      category: 'Knitwear',
      description: 'Pure cashmere cardigan',
      stockQuantity: 18,
      isActive: false, // Draft
      sizes: const ['One Size'],
      colors: const [
        ProductColor('Ivory', 0xFFF5F1EA),
      ],
    ),
    Product(
      id: 'p-3',
      sku: 'NOR-SLK-03',
      name: 'Silk Evening Blouse',
      price: 3899,
      imageUrl: 'https://example.com/blouse.jpg',
      category: 'Blouses',
      description: 'Refined silk evening wear',
      stockQuantity: 0, // Out of stock
      isActive: true,
      sizes: const ['S', 'M'],
      colors: const [],
    ),
  ];

  final testCategories = [
    const ProductCategory(id: 'cat-1', name: 'Shirts', slug: 'shirts'),
    const ProductCategory(id: 'cat-2', name: 'Knitwear', slug: 'knitwear'),
    const ProductCategory(id: 'cat-3', name: 'Blouses', slug: 'blouses'),
  ];

  Widget buildTestApp({
    Size viewport = const Size(1280, 900),
    List<Product>? products,
  }) {
    return ProviderScope(
      overrides: [
        productCatalogProvider.overrideWith(
          () => _FakeProductCatalogController(products ?? testProducts),
        ),
        catalogLoadStateProvider.overrideWith(
          _FakeCatalogLoadController.new,
        ),
        productCategoriesProvider.overrideWith(
          (ref) => testCategories,
        ),
      ],
      child: MaterialApp(
        theme: NorveTheme.light,
        home: const Scaffold(
          body: AdminProductsScreen(),
        ),
      ),
    );
  }

  testWidgets(
      'AdminProductsScreen renders page header, search bar, and NETIC product cards',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Verify Page Header
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Manage your boutique catalogue.'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-add-product')), findsOneWidget);

    // Verify Search & Filter Toolbar
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('All products'), findsOneWidget);
    expect(find.text('All categories'), findsOneWidget);

    // Verify Product Cards rendered
    expect(find.text('Oxford Cotton Shirt'), findsOneWidget);
    expect(find.text('Cashmere Knit Cardigan'), findsOneWidget);
    expect(find.text('Silk Evening Blouse'), findsOneWidget);

    // Verify Card Details
    expect(find.text('SKU: NOR-OFC-01'), findsOneWidget);
    expect(find.text('SHIRTS'), findsOneWidget);
    expect(find.text('₹2,499'), findsOneWidget);
    expect(find.text('₹3,499'), findsOneWidget); // Strikethrough original price
    expect(find.text('4 in stock'), findsOneWidget);
    expect(find.text('Low stock'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Sold out'), findsOneWidget);

    // Verify Actions exist on cards
    expect(
      find.byKey(const ValueKey('admin-edit-product-p-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-delete-product-p-1')),
      findsOneWidget,
    );
  });

  testWidgets('Search query filters the product card grid', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Enter search text
    await tester.enterText(find.byType(TextField), 'Cashmere');
    await tester.pumpAndSettle();

    expect(find.text('Cashmere Knit Cardigan'), findsOneWidget);
    expect(find.text('Oxford Cotton Shirt'), findsNothing);
    expect(find.text('Silk Evening Blouse'), findsNothing);
  });

  testWidgets('Delete button triggers confirmation dialog', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Tap delete on first product
    await tester.tap(find.byKey(const ValueKey('admin-delete-product-p-1')));
    await tester.pumpAndSettle();

    // Verify Confirmation Dialog
    expect(find.text('Delete product?'), findsOneWidget);
    expect(
      find.text(
        '“Oxford Cotton Shirt” will be permanently removed from the catalogue. Historical order item snapshots are retained.',
      ),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);

    // Confirm deletion
    await tester.tap(find.text('Delete product').last);
    await tester.pumpAndSettle();

    // Verify product removed from catalogue
    expect(find.text('Oxford Cotton Shirt'), findsNothing);
  });

  testWidgets('Responsive rendering: mobile layout without overflow',
      (tester) async {
    // Test on small mobile screen (390 x 844)
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Verify no rendering overflow exceptions
    expect(tester.takeException(), isNull);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Oxford Cotton Shirt'), findsOneWidget);
  });

  testWidgets('Responsive rendering: tablet layout without overflow',
      (tester) async {
    // 1. Tablet portrait at 768 x 546 (manual DevTools inspection size)
    tester.view.physicalSize = const Size(768, 546);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Oxford Cotton Shirt'), findsOneWidget);

    // 2. Tablet portrait at 768 x 1024
    tester.view.physicalSize = const Size(768, 1024);
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 3. Tablet landscape at 1024 x 768
    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Products'), findsOneWidget);
  });
}
