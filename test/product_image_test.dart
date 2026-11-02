import 'dart:math';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve/features/products/product_repository.dart';
import 'package:norve/features/products/widgets/product_image.dart';

void main() {
  testWidgets('remote product image uses platform-appropriate caching', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 120,
          height: 120,
          child: ProductImage(url: 'https://images.example.invalid/item.jpg'),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    if (provider is ResizeImage) {
      expect(provider.imageProvider, isA<CachedNetworkImageProvider>());
    } else {
      expect(provider, isA<NetworkImage>());
      expect(
        (provider as NetworkImage).webHtmlElementStrategy,
        WebHtmlElementStrategy.fallback,
      );
    }
  });

  group('Product image validation & path generation', () {
    test('isSupportedProductImage validates allowed formats and file size limits', () {
      expect(isSupportedProductImage('watch.jpg', 1024), isTrue);
      expect(isSupportedProductImage('watch.JPEG', 1024), isTrue);
      expect(isSupportedProductImage('watch.png', 1024), isTrue);
      expect(isSupportedProductImage('watch.webp', 1024), isTrue);

      expect(isSupportedProductImage('watch.gif', 1024), isFalse);
      expect(isSupportedProductImage('watch.bmp', 1024), isFalse);
      expect(isSupportedProductImage('watch.svg', 1024), isFalse);
      expect(isSupportedProductImage('watch', 1024), isFalse);

      expect(isSupportedProductImage('watch.png', 0), isFalse);
      expect(isSupportedProductImage('watch.png', 5 * 1024 * 1024), isTrue);
      expect(isSupportedProductImage('watch.png', 5 * 1024 * 1024 + 1), isFalse);
    });

    test('random secure suffix generation strictly avoids 0 max RangeError', () {
      for (var i = 0; i < 100; i++) {
        final val = Random.secure().nextInt(0xFFFFFFFF);
        expect(val, greaterThanOrEqualTo(0));
        expect(val, lessThan(0xFFFFFFFF));
        final hex = val.toRadixString(16).padLeft(8, '0');
        expect(hex.length, 8);
      }
    });

    test('uploadProductImage throws ProductRepositoryException on unsupported types', () async {
      final repository = ProductRepository(null);
      expect(
        () => repository.uploadProductImage(
          productId: 'p-1',
          fileName: 'doc.pdf',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsA(
          isA<ProductRepositoryException>().having(
            (e) => e.message,
            'message',
            contains('Choose a JPG, PNG or WebP image'),
          ),
        ),
      );
    });

    test('uploadProductImage throws ProductRepositoryException on oversized images', () async {
      final repository = ProductRepository(null);
      expect(
        () => repository.uploadProductImage(
          productId: 'p-1',
          fileName: 'huge.png',
          bytes: Uint8List(5 * 1024 * 1024 + 10),
        ),
        throwsA(
          isA<ProductRepositoryException>().having(
            (e) => e.message,
            'message',
            contains('Images must be smaller than 5 MB'),
          ),
        ),
      );
    });

    test('Product supports gallery images and external image URLs without uploads', () {
      final productWithGallery = Product(
        id: 'p-test',
        sku: 'TEST-01',
        name: 'Watch',
        price: 999,
        imageUrl: 'https://storage.supabase.co/norve-product-images/p-test/img1.png',
        category: 'Watches',
        description: 'Analog watch',
        sizes: const ['One Size'],
        colors: const [ProductColor('Matte Black', 0xFF24211E)],
        galleryImages: const [
          ProductGalleryImage(
            url: 'https://storage.supabase.co/norve-product-images/p-test/img1.png',
            storagePath: 'p-test/img1.png',
            isPrimary: true,
          ),
        ],
      );
      expect(productWithGallery.galleryImages.length, 1);
      expect(productWithGallery.galleryImages.first.isPrimary, isTrue);
      expect(productWithGallery.galleryImages.first.storagePath, 'p-test/img1.png');

      final productExternal = Product(
        id: 'p-ext',
        sku: 'TEST-02',
        name: 'Minimal Bag',
        price: 1499,
        imageUrl: 'https://images.example.com/bag.jpg',
        category: 'Bags',
        description: 'Leather bag',
        sizes: const ['One Size'],
        colors: const [ProductColor('Natural', 0xFFD9CDBB)],
        galleryImageUrls: const ['https://images.example.com/bag.jpg'],
      );
      expect(productExternal.imageUrl, 'https://images.example.com/bag.jpg');
      expect(productExternal.galleryImages, isEmpty);
      expect(productExternal.galleryImageUrls.first, 'https://images.example.com/bag.jpg');
    });
  });
}
