import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/admin/admin_product_form_screen.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve/features/products/product_catalog_provider.dart';
import 'package:norve/features/products/product_repository.dart';

class _FakeProductCatalogController extends ProductCatalogController {
  _FakeProductCatalogController();
  Product? lastSavedProduct;
  bool? lastCreateFlag;

  @override
  List<Product> build() => const [];

  @override
  Future<void> save(Product product, {required bool create}) async {
    lastSavedProduct = product;
    lastCreateFlag = create;
    state = [...state, product];
  }
}

class _FakeCatalogLoadController extends CatalogLoadController {
  @override
  CatalogLoadState build() => const CatalogLoadState(CatalogPhase.live);
}

void main() {
  final testCategories = [
    const ProductCategory(id: 'cat-1', name: 'Shirts', slug: 'shirts'),
    const ProductCategory(id: 'cat-2', name: 'Accessories', slug: 'accessories'),
  ];

  late _FakeProductCatalogController fakeCatalogController;

  Widget buildAddProductApp({
    Size viewport = const Size(1280, 900),
  }) {
    fakeCatalogController = _FakeProductCatalogController();
    return ProviderScope(
      overrides: [
        productCatalogProvider.overrideWith(() => fakeCatalogController),
        catalogLoadStateProvider.overrideWith(_FakeCatalogLoadController.new),
        productCategoriesProvider.overrideWith((ref) => testCategories),
      ],
      child: MaterialApp(
        theme: NorveTheme.light,
        home: const Scaffold(
          body: AdminProductFormScreen(),
        ),
      ),
    );
  }

  testWidgets(
      'AdminProductFormScreen renders Wolfpixel two-column Add Product layout on desktop',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildAddProductApp());
    await tester.pumpAndSettle();

    // Verify Page Header
    expect(find.text('Add New Product'), findsOneWidget);
    expect(
      find.text('Introduce a new piece into the boutique catalogue.'),
      findsOneWidget,
    );
    expect(find.text('Products'), findsOneWidget);
    expect(find.byKey(const ValueKey('save-product')), findsOneWidget);

    // Verify Left Column: Gallery & Image empty state
    expect(find.text('Product Gallery'), findsOneWidget);
    expect(find.text('No product imagery added'), findsOneWidget);
    expect(find.byKey(const ValueKey('pick-product-images')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-image-url')), findsOneWidget);

    // Verify Right Column: Structured Information Cards
    expect(find.text('Basic Information'), findsOneWidget);
    expect(find.byKey(const ValueKey('product-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-sku')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-description')), findsOneWidget);

    expect(find.text('Pricing & Valuation'), findsOneWidget);
    expect(find.byKey(const ValueKey('product-price')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-sale-price')), findsOneWidget);

    expect(find.text('Variants & Sizing Options'), findsOneWidget);
    expect(find.byKey(const ValueKey('product-requires-size')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-requires-color')), findsOneWidget);

    expect(find.text('Inventory & Stock Level'), findsOneWidget);
    expect(find.byKey(const ValueKey('product-stock')), findsOneWidget);

    expect(find.text('Storefront Visibility'), findsOneWidget);
    expect(find.byKey(const ValueKey('product-active')), findsOneWidget);
    expect(find.byKey(const ValueKey('save-product-footer')), findsOneWidget);
  });

  testWidgets('Validation triggers when required fields are empty',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildAddProductApp());
    await tester.pumpAndSettle();

    // Tap Create Product in header without entering required fields
    await tester.tap(find.byKey(const ValueKey('save-product')));
    await tester.pumpAndSettle();

    // Verify validation messages appear
    expect(find.text('This field is required.'), findsWidgets);
    expect(fakeCatalogController.lastSavedProduct, isNull);
  });

  testWidgets(
      'Pricing card calculates and displays discount savings percentage badge',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildAddProductApp());
    await tester.pumpAndSettle();

    // Enter selling price and compare-at regular price
    await tester.enterText(find.byKey(const ValueKey('product-price')), '2000');
    await tester.enterText(
        find.byKey(const ValueKey('product-sale-price')), '2500');
    await tester.pumpAndSettle();

    // Verify discount badge shows 20% OFF and savings amount
    expect(find.text('20% OFF'), findsOneWidget);
    expect(find.text('Customers save ₹500 on this product.'), findsOneWidget);
  });

  testWidgets('Creating product successfully dispatches to catalog provider',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildAddProductApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('product-name')),
      'Linen Structured Overshirt',
    );
    await tester.enterText(
      find.byKey(const ValueKey('product-sku')),
      'NOR-LSO-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('product-description')),
      'French flax linen overshirt with tailored collar.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('product-price')),
      '3800',
    );
    await tester.enterText(
      find.byKey(const ValueKey('product-image-url')),
      'https://example.com/overshirt.jpg',
    );
    await tester.enterText(
      find.byKey(const ValueKey('product-stock')),
      '20',
    );
    await tester.pumpAndSettle();

    // Scroll to footer action and save
    await tester.ensureVisible(find.byKey(const ValueKey('save-product-footer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-product-footer')));
    await tester.pumpAndSettle();

    expect(fakeCatalogController.lastSavedProduct, isNotNull);
    expect(fakeCatalogController.lastCreateFlag, isTrue);
    expect(
      fakeCatalogController.lastSavedProduct!.name,
      'Linen Structured Overshirt',
    );
    expect(fakeCatalogController.lastSavedProduct!.sku, 'NOR-LSO-01');
    expect(fakeCatalogController.lastSavedProduct!.price, 3800);
    expect(fakeCatalogController.lastSavedProduct!.stockQuantity, 20);
  });

  testWidgets(
      'Responsive layouts stack smoothly on mobile and tablet without overflow',
      (tester) async {
    // 1. Mobile viewport (390 x 844)
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildAddProductApp(viewport: const Size(390, 844)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Add New Product'), findsOneWidget);
    expect(find.text('Product Gallery'), findsOneWidget);
    expect(find.text('Basic Information'), findsOneWidget);

    // 2. Tablet viewport (768 x 1024)
    tester.view.physicalSize = const Size(768, 1024);
    await tester.pumpWidget(buildAddProductApp(viewport: const Size(768, 1024)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Add New Product'), findsOneWidget);
  });
}
