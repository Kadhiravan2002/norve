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
  _FakeProductCatalogController(this._initial);
  final List<Product> _initial;
  Product? lastSavedProduct;

  @override
  List<Product> build() => _initial;

  @override
  Future<void> save(Product product, {required bool create}) async {
    lastSavedProduct = product;
    state = [
      for (final p in state)
        if (p.id == product.id) product else p,
    ];
  }
}

class _FakeCatalogLoadController extends CatalogLoadController {
  @override
  CatalogLoadState build() => const CatalogLoadState(CatalogPhase.live);
}

void main() {
  final testProduct = Product(
    id: 'prod-edit-1',
    sku: 'NOR-CSH-01',
    name: 'Cashmere Relaxed Knit',
    price: 4999,
    originalPrice: 6999,
    imageUrl: 'https://example.com/img1.jpg',
    category: 'Knitwear',
    description: 'Sumptuous Mongolian cashmere cardigan with mother-of-pearl buttons.',
    stockQuantity: 12,
    isActive: true,
    requiresSize: true,
    requiresColor: true,
    sizes: const ['S', 'M', 'L'],
    colors: const [
      ProductColor('Charcoal', 0xFF24211E),
      ProductColor('Chalk', 0xFFF5F1EA),
    ],
    galleryImages: const [
      ProductGalleryImage(url: 'https://example.com/img1.jpg', isPrimary: true),
      ProductGalleryImage(url: 'https://example.com/img2.jpg', isPrimary: false),
    ],
    variants: const [
      ProductVariant(
        id: 'var-1',
        sku: 'NOR-CSH-01-S-CH',
        size: 'S',
        colorName: 'Charcoal',
        colorValue: 0xFF24211E,
        stockQuantity: 6,
      ),
      ProductVariant(
        id: 'var-2',
        sku: 'NOR-CSH-01-M-IV',
        size: 'M',
        colorName: 'Chalk',
        colorValue: 0xFFF5F1EA,
        stockQuantity: 6,
      ),
    ],
  );

  final testCategories = [
    const ProductCategory(id: 'cat-1', name: 'Shirts', slug: 'shirts'),
    const ProductCategory(id: 'cat-2', name: 'Knitwear', slug: 'knitwear'),
  ];

  late _FakeProductCatalogController fakeCatalogController;

  Widget buildEditApp({
    Size viewport = const Size(1280, 900),
    String? productId = 'prod-edit-1',
  }) {
    fakeCatalogController = _FakeProductCatalogController([testProduct]);
    return ProviderScope(
      overrides: [
        productCatalogProvider.overrideWith(() => fakeCatalogController),
        catalogLoadStateProvider.overrideWith(_FakeCatalogLoadController.new),
        productCategoriesProvider.overrideWith((ref) => testCategories),
      ],
      child: MaterialApp(
        theme: NorveTheme.light,
        home: Scaffold(
          body: AdminProductFormScreen(productId: productId),
        ),
      ),
    );
  }

  testWidgets(
      'AdminProductFormScreen renders Wolfpixel two-column edit layout on desktop',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildEditApp());
    await tester.pumpAndSettle();

    // Verify Page Header & Breadcrumbs
    expect(find.text('Edit Product'), findsOneWidget);
    expect(
      find.text('Manage product information, pricing and availability.'),
      findsOneWidget,
    );
    expect(find.text('Products'), findsOneWidget); // Breadcrumb
    expect(find.byKey(const ValueKey('save-product')), findsOneWidget);

    // Verify Left Column: Gallery Card & Thumbnails
    expect(find.text('Product Gallery'), findsOneWidget);
    expect(find.text('Primary Image'), findsOneWidget);
    expect(find.text('GALLERY THUMBNAILS'), findsOneWidget);
    expect(find.byKey(const ValueKey('pick-product-images')), findsOneWidget);

    // Verify Right Column: Structured Information Sections
    expect(find.text('Basic Information'), findsOneWidget);
    expect(find.text('Pricing & Valuation'), findsOneWidget);
    expect(find.text('External Image Source'), findsOneWidget);
    expect(find.text('Variants & Sizing Options'), findsOneWidget);
    expect(find.text('Inventory & Stock Level'), findsOneWidget);
    expect(find.text('Storefront Visibility'), findsOneWidget);

    // Verify Pre-populated Field Values
    expect(find.text('Cashmere Relaxed Knit'), findsOneWidget);
    expect(find.text('NOR-CSH-01'), findsOneWidget);
    expect(find.text('4999'), findsOneWidget);
    expect(find.text('6999'), findsOneWidget);
    expect(find.text('12 Total Units in Stock'), findsOneWidget);
    expect(find.text('Active in customer catalogue'), findsOneWidget);
  });

  testWidgets('Selecting a thumbnail updates preview and allows setting as primary',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildEditApp());
    await tester.pumpAndSettle();

    // Initially, image 0 is primary
    expect(find.text('Primary Image'), findsOneWidget);

    // Tap on second thumbnail in thumbnail strip
    await tester.tap(find.byKey(const ValueKey('gallery-thumbnail-1')));
    await tester.pumpAndSettle();

    // The 'Set as Primary' button should appear for the non-primary preview
    expect(find.text('Set as Primary'), findsOneWidget);

    // Tap 'Set as Primary'
    await tester.tap(find.text('Set as Primary'));
    await tester.pumpAndSettle();

    // Now image 1 is primary!
    expect(find.text('Primary Image'), findsOneWidget);
    expect(find.text('Set as Primary'), findsNothing);
  });

  testWidgets('Saving changes updates product through catalog provider',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildEditApp());
    await tester.pumpAndSettle();

    // Modify product title
    await tester.enterText(
      find.byKey(const ValueKey('product-name')),
      'Cashmere Relaxed Knit V2',
    );
    await tester.pumpAndSettle();

    // Modify selling price
    await tester.enterText(
      find.byKey(const ValueKey('product-price')),
      '5499',
    );
    await tester.pumpAndSettle();

    // Tap Save Changes
    await tester.tap(find.byKey(const ValueKey('save-product')));
    await tester.pumpAndSettle();

    expect(fakeCatalogController.lastSavedProduct, isNotNull);
    expect(
      fakeCatalogController.lastSavedProduct!.name,
      'Cashmere Relaxed Knit V2',
    );
    expect(fakeCatalogController.lastSavedProduct!.price, 5499);
  });

  testWidgets('Responsive layouts render smoothly on mobile and tablet without overflow',
      (tester) async {
    // 1. Mobile viewport (390 x 844)
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildEditApp(viewport: const Size(390, 844)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Edit Product'), findsOneWidget);
    expect(find.text('Product Gallery'), findsOneWidget);
    expect(find.text('Basic Information'), findsOneWidget);

    // 2. Tablet viewport (768 x 1024)
    tester.view.physicalSize = const Size(768, 1024);
    await tester.pumpWidget(buildEditApp(viewport: const Size(768, 1024)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Edit Product'), findsOneWidget);
  });
}
