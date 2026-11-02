import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/admin/admin_product_form_screen.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve/features/products/product_repository.dart';

class _MockProductRepository extends ProductRepository {
  _MockProductRepository() : super(null);

  final List<Product> createdProducts = [];
  final List<String> deletedImagePaths = [];
  bool failUpload = false;
  bool failCreate = false;

  @override
  Future<List<Product>> fetchProducts() async => [];

  @override
  Future<List<ProductCategory>> fetchCategories() async => [
        const ProductCategory(
          id: 'cat-watches',
          name: 'Watches',
          slug: 'watches',
          description: 'Timeless pieces',
        ),
      ];

  @override
  Future<ProductGalleryImage> uploadProductImage({
    required String productId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (failUpload) {
      throw const ProductRepositoryException('Storage upload failed: network error');
    }
    final extension = fileName.split('.').last.toLowerCase();
    if (!supportedProductImageTypes.contains(extension)) {
      throw const ProductRepositoryException('Choose a JPG, PNG or WebP image.');
    }
    if (!isSupportedProductImage(fileName, bytes.length)) {
      throw const ProductRepositoryException('Images must be smaller than 5 MB.');
    }
    final suffix = 'a1b2c3d4';
    final path = '$productId/test-$suffix.$extension';
    return ProductGalleryImage(
      url: 'https://storage.supabase.co/norve-product-images/$path',
      storagePath: path,
      isPrimary: true,
    );
  }

  @override
  Future<void> deleteUploadedImages(List<String> paths) async {
    deletedImagePaths.addAll(paths);
  }

  @override
  Future<Product> create(Product product) async {
    if (failCreate) {
      throw Exception('Database constraint violation: duplicate SKU');
    }
    createdProducts.add(product);
    return product;
  }
}

void main() {
  testWidgets('admin product form creates product without uploaded image using external URL', (
    tester,
  ) async {
    final mockRepo = _MockProductRepository();
    final container = ProviderContainer(
      overrides: [
        productRepositoryProvider.overrideWithValue(mockRepo),
        productCategoriesProvider.overrideWith(
          (ref) => Future.value([
            const ProductCategory(
              id: 'cat-watches',
              name: 'Watches',
              slug: 'watches',
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1024, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: NorveTheme.light,
          home: const Scaffold(body: AdminProductFormScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('product-name')), 'Analog Minimal Watch');
    await tester.enterText(find.byKey(const ValueKey('product-sku')), 'NORVE-W01');
    await tester.enterText(find.byKey(const ValueKey('product-description')), 'Matte black watch.');
    await tester.enterText(find.byKey(const ValueKey('product-price')), '1499');
    await tester.enterText(
      find.byKey(const ValueKey('product-image-url')),
      'https://example.com/watch.jpg',
    );

    // Disable variant requirements for simple single-piece product
    await tester.tap(find.byKey(const ValueKey('product-requires-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('product-requires-color')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('save-product')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('save-product')));
    await tester.pumpAndSettle();

    expect(mockRepo.createdProducts, hasLength(1));
    final created = mockRepo.createdProducts.first;
    expect(created.name, 'Analog Minimal Watch');
    expect(created.sku, 'NORVE-W01');
    expect(created.price, 1499);
    expect(created.imageUrl, 'https://example.com/watch.jpg');
    expect(created.galleryImages.first.url, 'https://example.com/watch.jpg');
    expect(created.galleryImages.first.storagePath, isNull);
  });

  testWidgets('admin product form cleans up uploaded images if product save fails', (
    tester,
  ) async {
    final mockRepo = _MockProductRepository()..failCreate = true;
    final container = ProviderContainer(
      overrides: [
        productRepositoryProvider.overrideWithValue(mockRepo),
        productCategoriesProvider.overrideWith(
          (ref) => Future.value([
            const ProductCategory(
              id: 'cat-watches',
              name: 'Watches',
              slug: 'watches',
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1024, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: NorveTheme.light,
          home: const Scaffold(body: AdminProductFormScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('product-name')), 'Failing Product');
    await tester.enterText(find.byKey(const ValueKey('product-sku')), 'NORVE-DUP');
    await tester.enterText(find.byKey(const ValueKey('product-description')), 'Test description');
    await tester.enterText(find.byKey(const ValueKey('product-price')), '999');
    await tester.enterText(
      find.byKey(const ValueKey('product-image-url')),
      'https://example.com/fallback.jpg',
    );

    await tester.tap(find.byKey(const ValueKey('product-requires-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('product-requires-color')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('save-product')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('save-product')));
    await tester.pumpAndSettle();

    expect(find.text('Exception: Database constraint violation: duplicate SKU'), findsOneWidget);
    expect(mockRepo.createdProducts, isEmpty);
  });
}
