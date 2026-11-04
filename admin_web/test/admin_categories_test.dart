import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/features/admin/admin_categories_screen.dart';
import 'package:norve/features/products/product_catalog_provider.dart';
import 'package:norve/features/products/product_repository.dart';

class _FakeProductRepository extends ProductRepository {
  _FakeProductRepository(this.categories) : super(null);

  List<ProductCategory> categories;
  int saveCount = 0;
  int deleteCount = 0;
  ProductCategory? lastSaved;
  String? lastDeletedId;

  @override
  Future<List<ProductCategory>> fetchCategories() async => categories;

  @override
  Future<ProductCategory> saveCategory(
    ProductCategory category, {
    required bool create,
  }) async {
    saveCount++;
    lastSaved = category;
    final saved = ProductCategory(
      id: create ? 'cat-${categories.length + 1}' : category.id,
      name: category.name,
      slug: category.name.toLowerCase().replaceAll(' ', '-'),
      description: category.description,
      imageUrl: category.imageUrl,
      productCount: category.productCount,
    );
    if (create) {
      categories = [...categories, saved];
    } else {
      categories = [
        for (final c in categories) if (c.id == category.id) saved else c,
      ];
    }
    return saved;
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    deleteCount++;
    lastDeletedId = categoryId;
    categories = categories.where((c) => c.id != categoryId).toList();
  }
}

class _FakeCatalogLoadController extends CatalogLoadController {
  @override
  CatalogLoadState build() => const CatalogLoadState(CatalogPhase.live);
}

void main() {
  final sampleCategories = [
    const ProductCategory(
      id: 'cat-1',
      name: 'Outerwear',
      slug: 'outerwear',
      description: 'Handcrafted cashmere coats and structural blazers.',
      imageUrl: 'https://example.com/outerwear.jpg',
      productCount: 14,
    ),
    const ProductCategory(
      id: 'cat-2',
      name: 'Knitwear',
      slug: 'knitwear',
      description: 'Fine-gauge merino and tactile brushed mohair knits.',
      imageUrl: 'https://example.com/knitwear.jpg',
      productCount: 8,
    ),
    const ProductCategory(
      id: 'cat-3',
      name: 'Archive Collection',
      slug: 'archive-collection',
      description: 'Past season archival silhouettes.',
      imageUrl: null,
      productCount: 0,
    ),
  ];

  Widget buildTestApp({
    required _FakeProductRepository repo,
    Size surfaceSize = const Size(1280, 900),
  }) {
    return ProviderScope(
      overrides: [
        productRepositoryProvider.overrideWithValue(repo),
        productCategoriesProvider.overrideWith((ref) => repo.fetchCategories()),
        catalogLoadStateProvider.overrideWith(
          () => _FakeCatalogLoadController(),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: AdminCategoriesScreen()),
      ),
    );
  }

  testWidgets('renders categories header, KPI metrics and category cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = _FakeProductRepository(sampleCategories);
    await tester.pumpWidget(buildTestApp(repo: repo));
    await tester.pumpAndSettle();

    // Verify Page Header & Add Category action
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Add category'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-add-category')), findsOneWidget);

    // Verify KPI Summary Row
    expect(find.text('Total Categories'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // 3 categories
    expect(find.text('Total Products'), findsOneWidget);
    expect(find.text('22'), findsOneWidget); // 14 + 8 + 0 = 22 products
    expect(find.text('Active Collections'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // 2 populated
    expect(find.text('Empty Collections'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // 1 empty

    // Verify Category Cards
    expect(find.text('Outerwear'), findsOneWidget);
    expect(find.text('14 Products'), findsOneWidget);
    expect(find.text('Knitwear'), findsOneWidget);
    expect(find.text('8 Products'), findsOneWidget);
    expect(find.text('Archive Collection'), findsOneWidget);
    expect(find.text('0 Products'), findsOneWidget);
  });

  testWidgets('filters categories using search field', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = _FakeProductRepository(sampleCategories);
    await tester.pumpWidget(buildTestApp(repo: repo));
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField).first;
    await tester.enterText(searchField, 'Outer');
    await tester.pumpAndSettle();

    expect(find.text('Outerwear'), findsOneWidget);
    expect(find.text('Knitwear'), findsNothing);
    expect(find.text('Archive Collection'), findsNothing);

    // Search with no results
    await tester.enterText(searchField, 'Shoes');
    await tester.pumpAndSettle();

    expect(find.text('No matching categories found'), findsOneWidget);
    expect(find.text('Clear search'), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();

    expect(find.text('Outerwear'), findsOneWidget);
    expect(find.text('Knitwear'), findsOneWidget);
  });

  testWidgets('toggles between Grid View and Table View', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = _FakeProductRepository(sampleCategories);
    await tester.pumpWidget(buildTestApp(repo: repo));
    await tester.pumpAndSettle();

    // Toggle to Table View
    final tableToggle = find.byTooltip('Table View');
    expect(tableToggle, findsOneWidget);
    await tester.tap(tableToggle);
    await tester.pumpAndSettle();

    // Headers in table view
    expect(find.text('CATEGORY'), findsOneWidget);
    expect(find.text('DESCRIPTION'), findsOneWidget);
    expect(find.text('PRODUCTS'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('ACTIONS'), findsOneWidget);

    // Toggle back to Grid View
    final gridToggle = find.byTooltip('Grid View');
    expect(gridToggle, findsOneWidget);
    await tester.tap(gridToggle);
    await tester.pumpAndSettle();

    expect(find.text('Total Categories'), findsOneWidget);
  });

  testWidgets('opens Add Category 2-column form modal and creates category', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = _FakeProductRepository(sampleCategories);
    await tester.pumpWidget(buildTestApp(repo: repo));
    await tester.pumpAndSettle();

    // Click Add category
    await tester.tap(find.byKey(const ValueKey('admin-add-category')));
    await tester.pumpAndSettle();

    // Modal is open
    expect(find.text('General Information'), findsOneWidget);
    expect(find.text('Category Media'), findsOneWidget);
    expect(find.text('Live Preview'), findsOneWidget);
    expect(find.text('Save category'), findsOneWidget);

    // Try submitting without name (validation error)
    await tester.tap(find.text('Save category'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a category name.'), findsOneWidget);

    // Enter valid details
    final nameField = find.widgetWithText(TextFormField, 'Category name');
    final descField = find.widgetWithText(TextFormField, 'Description');
    await tester.enterText(nameField, 'Accessories');
    await tester.enterText(descField, 'Luxury leather goods and silk scarves.');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save category'));
    await tester.pumpAndSettle();

    expect(repo.saveCount, 1);
    expect(repo.lastSaved?.name, 'Accessories');
  });

  testWidgets('opens Edit Category modal without duplicate floating labels and with Image URL (Optional)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = _FakeProductRepository(sampleCategories);
    await tester.pumpWidget(buildTestApp(repo: repo));
    await tester.pumpAndSettle();

    // Switch to table view to easily tap edit on Outerwear
    final tableToggle = find.byTooltip('Table View');
    await tester.tap(tableToggle);
    await tester.pumpAndSettle();

    // Tap edit on Outerwear
    await tester.tap(find.byTooltip('Edit Outerwear'));
    await tester.pumpAndSettle();

    // Modal title
    expect(find.text('Edit category'), findsOneWidget);

    // Labels above fields
    expect(find.text('Category Name'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Image URL (Optional)'), findsOneWidget);

    // Verify input decorations have null labelText (no floating labels)
    final textFields = tester
        .widgetList<TextField>(
          find.descendant(
            of: find.byType(TextFormField),
            matching: find.byType(TextField),
          ),
        )
        .toList();
    expect(textFields.length, 3);
    for (final field in textFields) {
      expect(field.decoration?.labelText, isNull);
    }

    // Pre-filled values inside dialog
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Outerwear'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text(
          'Handcrafted cashmere coats and structural blazers.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('https://example.com/outerwear.jpg'),
      ),
      findsOneWidget,
    );

    // Save changes
    await tester.tap(find.text('Save category'));
    await tester.pumpAndSettle();

    expect(repo.saveCount, 1);
    expect(repo.lastSaved?.id, 'cat-1');
  });

  testWidgets('prevents deleting populated category and allows empty category', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = _FakeProductRepository(sampleCategories);
    await tester.pumpWidget(buildTestApp(repo: repo));
    await tester.pumpAndSettle();

    // Attempt to delete populated category (Outerwear, 14 products)
    final deleteOuterwear = find.byTooltip('Delete Outerwear');
    expect(deleteOuterwear, findsOneWidget);
    await tester.tap(deleteOuterwear);
    await tester.pumpAndSettle();

    // Warning dialog appears
    expect(find.text('Category contains products'), findsOneWidget);
    expect(find.textContaining('14 products in this category'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(repo.deleteCount, 0);

    // Attempt to delete empty category (Archive Collection, 0 products)
    final deleteArchive = find.byTooltip('Delete Archive Collection');
    expect(deleteArchive, findsOneWidget);
    await tester.tap(deleteArchive);
    await tester.pumpAndSettle();

    // Confirmation dialog appears
    expect(find.text('Delete category?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete category'));
    await tester.pumpAndSettle();

    expect(repo.deleteCount, 1);
    expect(repo.lastDeletedId, 'cat-3');
  });

  testWidgets('renders responsive layout on mobile without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = _FakeProductRepository(sampleCategories);
    await tester.pumpWidget(buildTestApp(repo: repo));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Total Categories'), findsOneWidget);
    expect(find.text('Outerwear'), findsOneWidget);
  });
}
