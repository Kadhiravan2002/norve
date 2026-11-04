import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/admin/admin_inventory_screen.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve/features/products/product_catalog_provider.dart';
import 'package:norve/features/products/product_repository.dart';

class _FakeProductCatalogController extends ProductCatalogController {
  _FakeProductCatalogController(this._initial);
  final List<Product> _initial;
  int refreshCount = 0;

  @override
  List<Product> build() => _initial;

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
}

class _FakeCatalogLoadController extends CatalogLoadController {
  @override
  CatalogLoadState build() => const CatalogLoadState(CatalogPhase.live);
}

class _FakeProductRepository extends ProductRepository {
  _FakeProductRepository() : super(null);

  String? lastUpdatedVariantId;
  int? lastUpdatedQuantity;
  bool? lastUpdatedAvailability;
  int updateCallCount = 0;

  @override
  Future<void> setVariantStock(
    String variantId,
    int? quantity, {
    bool? isAvailable,
  }) async {
    updateCallCount++;
    lastUpdatedVariantId = variantId;
    lastUpdatedQuantity = quantity;
    lastUpdatedAvailability = isAvailable;
  }
}

void main() {
  final sampleProducts = [
    Product(
      id: 'prod-1',
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
      variants: const [
        ProductVariant(
          id: 'var-1a',
          sku: 'NOR-OFC-01-W-M',
          size: 'M',
          colorName: 'White',
          colorValue: 0xFFFFFFFF,
          stockQuantity: 3, // Low stock
          isAvailable: true,
        ),
        ProductVariant(
          id: 'var-1b',
          sku: 'NOR-OFC-01-C-L',
          size: 'L',
          colorName: 'Charcoal',
          colorValue: 0xFF24211E,
          stockQuantity: 1, // Low stock
          isAvailable: true,
        ),
      ],
    ),
    Product(
      id: 'prod-2',
      sku: 'NOR-CSH-02',
      name: 'Cashmere Knit Cardigan',
      price: 5999,
      imageUrl: 'https://example.com/knit.jpg',
      category: 'Knitwear',
      description: 'Pure cashmere cardigan',
      stockQuantity: 18, // In stock
      isActive: true,
      sizes: const ['One Size'],
      colors: const [
        ProductColor('Ivory', 0xFFF5F1EA),
      ],
      variants: const [
        ProductVariant(
          id: 'var-2a',
          sku: 'NOR-CSH-02-IV-OS',
          size: 'One Size',
          colorName: 'Ivory',
          colorValue: 0xFFF5F1EA,
          stockQuantity: 18,
          isAvailable: true,
        ),
      ],
    ),
    Product(
      id: 'prod-3',
      sku: 'NOR-BLZ-03',
      name: 'Structured Wool Blazer',
      price: 8999,
      imageUrl: 'https://example.com/blazer.jpg',
      category: 'Tailoring',
      description: 'Hand-tailored blazer',
      stockQuantity: 0, // Out of stock
      isActive: false, // Draft
      sizes: const ['40R'],
      colors: const [
        ProductColor('Charcoal', 0xFF24211E),
      ],
      variants: const [
        ProductVariant(
          id: 'var-3a',
          sku: 'NOR-BLZ-03-CH-40',
          size: '40R',
          colorName: 'Charcoal',
          colorValue: 0xFF24211E,
          stockQuantity: 0, // Out of stock
          isAvailable: false,
        ),
      ],
    ),
  ];

  final sampleCategories = [
    const ProductCategory(
      id: 'cat-1',
      name: 'Shirts',
      slug: 'shirts',
      description: '',
    ),
    const ProductCategory(
      id: 'cat-2',
      name: 'Knitwear',
      slug: 'knitwear',
      description: '',
    ),
    const ProductCategory(
      id: 'cat-3',
      name: 'Tailoring',
      slug: 'tailoring',
      description: '',
    ),
  ];

  Widget buildTestWidget({
    List<Product>? products,
    _FakeProductRepository? repo,
    Size surfaceSize = const Size(1280, 900),
  }) {
    final prods = products ?? sampleProducts;
    final repository = repo ?? _FakeProductRepository();

    return ProviderScope(
      overrides: [
        productRepositoryProvider.overrideWithValue(repository),
        productCatalogProvider.overrideWith(
          () => _FakeProductCatalogController(prods),
        ),
        catalogLoadStateProvider.overrideWith(
          () => _FakeCatalogLoadController(),
        ),
        productCategoriesProvider.overrideWith(
          (ref) async => sampleCategories,
        ),
      ],
      child: MaterialApp(
        theme: NorveTheme.light,
        home: const AdminInventoryScreen(),
      ),
    );
  }

  testWidgets('renders page header, KPI metrics row, toolbar and table', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Page header
    expect(find.text('Inventory'), findsOneWidget);
    expect(
      find.text(
        'Stock is updated per variant. Order placement continues to deduct stock atomically.',
      ),
      findsOneWidget,
    );

    // KPI Summary Metrics
    expect(find.text('Total Products'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // 3 products
    expect(find.text('Total Stock Units'), findsOneWidget);
    expect(find.text('22'), findsOneWidget); // 4 + 18 + 0 = 22 units
    expect(find.text('Low Stock Variants'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // var-1a (3) + var-1b (1) = 2
    expect(find.text('Out of Stock'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // var-3a (0) = 1

    // Search and Filters
    expect(find.byKey(const ValueKey('inventory-search')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('inventory-category-All categories')),
      findsOneWidget,
    );

    // Products in Table
    expect(find.text('Oxford Cotton Shirt'), findsOneWidget);
    expect(find.text('Cashmere Knit Cardigan'), findsOneWidget);
    expect(find.text('Structured Wool Blazer'), findsOneWidget);

    // Stock Statuses
    expect(find.text('LOW · 4'), findsOneWidget);
    expect(find.text('OUT OF STOCK'), findsOneWidget);
    expect(find.text('18 units'), findsAtLeastNWidgets(1));
  });

  testWidgets('filters products by search query matching name and SKU', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final searchField = find.byKey(const ValueKey('inventory-search'));

    // Search by product name
    await tester.enterText(searchField, 'Cashmere');
    await tester.pumpAndSettle();

    expect(find.text('Cashmere Knit Cardigan'), findsOneWidget);
    expect(find.text('Oxford Cotton Shirt'), findsNothing);
    expect(find.text('Structured Wool Blazer'), findsNothing);

    // Search by SKU
    await tester.enterText(searchField, 'NOR-BLZ');
    await tester.pumpAndSettle();

    expect(find.text('Structured Wool Blazer'), findsOneWidget);
    expect(find.text('Cashmere Knit Cardigan'), findsNothing);
  });

  testWidgets('filters products by category dropdown', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap category dropdown
    final categoryDropdown = find.byKey(
      const ValueKey('inventory-category-All categories'),
    );
    await tester.tap(categoryDropdown);
    await tester.pumpAndSettle();

    // Select 'Knitwear'
    await tester.tap(find.text('Knitwear').last);
    await tester.pumpAndSettle();

    expect(find.text('Cashmere Knit Cardigan'), findsOneWidget);
    expect(find.text('Oxford Cotton Shirt'), findsNothing);
    expect(find.text('Structured Wool Blazer'), findsNothing);
  });

  testWidgets('filters products by stock level', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Open stock filter dropdown
    final stockDropdown = find.byKey(
      const ValueKey('inventory-stock-filter-all'),
    );
    await tester.tap(stockDropdown);
    await tester.pumpAndSettle();

    // Select 'Out of stock (0)'
    await tester.tap(find.text('Out of stock (0)').last);
    await tester.pumpAndSettle();

    expect(find.text('Structured Wool Blazer'), findsOneWidget);
    expect(find.text('Oxford Cotton Shirt'), findsNothing);
    expect(find.text('Cashmere Knit Cardigan'), findsNothing);
  });

  testWidgets('expands product row to reveal variant stock details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Oxford Cotton Shirt variants shouldn't be expanded initially
    expect(find.text('NOR-OFC-01-W-M'), findsNothing);

    // Tap the product row to expand
    final productTile = find.byKey(const ValueKey('inventory-prod-1'));
    await tester.tap(productTile);
    await tester.pumpAndSettle();

    // Variants are now visible
    expect(find.text('VARIANT STOCK SPECIFICATIONS'), findsOneWidget);
    expect(find.text('NOR-OFC-01-W-M'), findsOneWidget);
    expect(find.text('NOR-OFC-01-C-L'), findsOneWidget);
    expect(find.text('M · White'), findsOneWidget);
    expect(find.text('L · Charcoal'), findsOneWidget);
    expect(find.text('Manage variants'), findsOneWidget);
  });

  testWidgets('edits variant stock quantity and saves successfully via repository', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = _FakeProductRepository();
    await tester.pumpWidget(buildTestWidget(repo: repo));
    await tester.pumpAndSettle();

    // Expand Oxford Cotton Shirt
    await tester.tap(find.byKey(const ValueKey('inventory-prod-1')));
    await tester.pumpAndSettle();

    // Find the stock input text field for the first variant
    final stockInputs = find.widgetWithText(TextField, 'Stock');
    expect(stockInputs, findsAtLeastNWidgets(2));

    // Change stock quantity to 12
    await tester.enterText(stockInputs.first, '12');
    await tester.pumpAndSettle();

    // Click Save stock
    final saveButtons = find.byTooltip('Save stock');
    expect(saveButtons, findsAtLeastNWidgets(2));
    await tester.tap(saveButtons.first);
    await tester.pumpAndSettle();

    // Verify repository was called with correct parameters
    expect(repo.updateCallCount, 1);
    expect(repo.lastUpdatedVariantId, 'var-1a');
    expect(repo.lastUpdatedQuantity, 12);
    expect(find.text('Stock updated.'), findsOneWidget);
  });

  testWidgets('toggles variant storefront availability via switch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = _FakeProductRepository();
    await tester.pumpWidget(buildTestWidget(repo: repo));
    await tester.pumpAndSettle();

    // Expand Oxford Cotton Shirt
    await tester.tap(find.byKey(const ValueKey('inventory-prod-1')));
    await tester.pumpAndSettle();

    // Toggle switch on first variant (currently true -> change to false)
    final switches = find.byType(Switch);
    expect(switches, findsAtLeastNWidgets(2));

    await tester.tap(switches.first);
    await tester.pumpAndSettle();

    expect(repo.updateCallCount, 1);
    expect(repo.lastUpdatedVariantId, 'var-1a');
    expect(repo.lastUpdatedAvailability, false);
  });

  testWidgets('renders responsive compact layout on mobile without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      buildTestWidget(surfaceSize: const Size(390, 844)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Total Products'), findsOneWidget);
    expect(find.text('Oxford Cotton Shirt'), findsOneWidget);

    // Expand on mobile
    await tester.tap(find.byKey(const ValueKey('inventory-prod-1')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('M · White'), findsOneWidget);
    expect(find.byTooltip('Save stock'), findsAtLeastNWidgets(1));
  });

  testWidgets('shows empty state when no products match filters and allows clearing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final searchField = find.byKey(const ValueKey('inventory-search'));
    await tester.enterText(searchField, 'NonExistentItem999');
    await tester.pumpAndSettle();

    expect(find.text('No products match these filters.'), findsOneWidget);
    expect(find.text('Clear filters'), findsOneWidget);

    // Tap clear filters
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.text('Oxford Cotton Shirt'), findsOneWidget);
  });
}
