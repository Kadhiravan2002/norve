import 'package:flutter_test/flutter_test.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve/features/products/product_repository.dart';

void main() {
  test(
    'category mapping includes product count and optional image metadata',
    () {
      final category = ProductCategory.fromSupabaseRow({
        'id': 'cat-1',
        'name': 'Knitwear',
        'slug': 'knitwear',
        'description': 'Considered layers',
        'image_url': 'https://example.com/knitwear.jpg',
        'products': [
          {'count': 3},
        ],
      });
      expect(category.name, 'Knitwear');
      expect(category.productCount, 3);
      expect(category.description, 'Considered layers');
      expect(category.imageUrl, 'https://example.com/knitwear.jpg');
    },
  );

  test('product mapping preserves image order and variant commerce data', () {
    final product = Product.fromSupabaseRow({
      'id': 'product-1',
      'sku': 'NORVE-TEE-01',
      'name': 'Cotton Tee',
      'description': 'Cotton',
      'price_inr': 999,
      'original_price_inr': 1299,
      'image_url': 'https://storage.example/primary.jpg',
      'is_active': true,
      'requires_size': true,
      'requires_color': false,
      'created_at': '2026-10-20T12:00:00Z',
      'categories': {'name': 'T-shirts'},
      'product_images': [
        {
          'image_url': 'https://storage.example/second.jpg',
          'storage_path': 'product-1/second.jpg',
          'sort_order': 1,
          'is_primary': false,
        },
        {
          'image_url': 'https://storage.example/primary.jpg',
          'storage_path': 'product-1/primary.jpg',
          'sort_order': 0,
          'is_primary': true,
        },
      ],
      'product_variants': [
        {
          'id': 'variant-1',
          'sku': 'NORVE-TEE-01-M',
          'size': 'M',
          'color_name': 'Standard',
          'color_hex': '#F5F1EA',
          'price_override_inr': 899,
          'stock_quantity': 4,
          'is_available': true,
        },
      ],
    });
    expect(product.sku, 'NORVE-TEE-01');
    expect(product.requiresSize, isTrue);
    expect(product.requiresColor, isFalse);
    expect(product.galleryImageUrls, [
      'https://storage.example/primary.jpg',
      'https://storage.example/second.jpg',
    ]);
    expect(product.variants.single.id, 'variant-1');
    expect(product.variants.single.priceOverride, 899);
    expect(product.isPurchasable, isTrue);
    expect(product.imageUrl, 'https://storage.example/primary.jpg');
    expect(product.galleryImageUrls.first, product.imageUrl);
  });

  test('image file validation accepts formats and enforces size limits', () {
    for (final extension in ['jpg', 'jpeg', 'png', 'webp']) {
      expect(isSupportedProductImage('coat.$extension', 32), isTrue);
    }
    expect(isSupportedProductImage('coat.svg', 32), isFalse);
    expect(isSupportedProductImage('coat.jpg', 0), isFalse);
    expect(
      isSupportedProductImage('coat.png', maxProductImageBytes + 1),
      isFalse,
    );
    expect(isSupportedProductImage('coat.jpeg', maxProductImageBytes), isTrue);
  });
}
