import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'product.dart';

const productImageBucket = 'norve-product-images';
const maxProductImageBytes = 5 * 1024 * 1024;
const supportedProductImageTypes = {'jpg', 'jpeg', 'png', 'webp'};

bool isSupportedProductImage(String fileName, int byteLength) {
  final extension = fileName.split('.').last.toLowerCase();
  return supportedProductImageTypes.contains(extension) &&
      byteLength > 0 &&
      byteLength <= maxProductImageBytes;
}

class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
    this.imageUrl,
    this.productCount = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final String? imageUrl;
  final int productCount;

  factory ProductCategory.fromSupabaseRow(Map<String, dynamic> row) {
    final products = row['products'];
    final countRow = products is List
        ? products.whereType<Map>().firstOrNull
        : null;
    final productCount = countRow?['count'];
    final id = row['id']?.toString();
    final name = row['name']?.toString();
    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      throw const FormatException(
        'Supabase returned a category without its required ID or name.',
      );
    }
    return ProductCategory(
      id: id,
      name: name,
      slug: row['slug']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      imageUrl: row['image_url']?.toString(),
      productCount: productCount is num ? productCount.toInt() : 0,
    );
  }
}

class ProductRepositoryException implements Exception {
  const ProductRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ProductRepository {
  const ProductRepository(this._client);
  final SupabaseClient? _client;

  Future<List<Product>> fetchProducts() async {
    final rows = await _requireClient()
        .from('products')
        .select(
          'id,sku,name,description,price_inr,original_price_inr,image_url,is_active,requires_size,requires_color,created_at,category_id,categories(id,name),product_images(image_url,storage_path,sort_order,is_primary),product_variants(id,sku,size,color_name,color_hex,price_override_inr,stock_quantity,is_available)',
        )
        .order('created_at', ascending: false);
    return rows
        .map((row) => Product.fromSupabaseRow(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<ProductCategory>> fetchCategories() async {
    final rows = await _requireClient()
        .from('categories')
        .select('id,name,slug,description,image_url,products(count)')
        .order('name');
    return rows
        .map(
          (row) =>
              ProductCategory.fromSupabaseRow(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<ProductCategory> saveCategory(
    ProductCategory category, {
    required bool create,
  }) async {
    final client = _requireClient();
    final values = {
      'name': category.name.trim(),
      'slug': _slugify(category.name),
      'description': category.description.trim(),
      'image_url': category.imageUrl?.trim().isEmpty == true
          ? null
          : category.imageUrl?.trim(),
    };
    final row = create
        ? await client
              .from('categories')
              .insert(values)
              .select('id,name,slug,description,image_url')
              .single()
        : await client
              .from('categories')
              .update(values)
              .eq('id', category.id)
              .select('id,name,slug,description,image_url')
              .single();
    return ProductCategory.fromSupabaseRow(Map<String, dynamic>.from(row));
  }

  Future<void> deleteCategory(String categoryId) async {
    final result = await _requireClient()
        .from('categories')
        .delete()
        .eq('id', categoryId)
        .select('id');
    if (result.isEmpty) {
      throw const ProductRepositoryException(
        'Category was not deleted. It may still contain products or access may be denied.',
      );
    }
  }

  Future<Product> create(Product product) => _save(product, create: true);
  Future<Product> update(Product product) => _save(product, create: false);

  Future<Product> _save(Product product, {required bool create}) async {
    final client = _requireClient();
    if (product.sku.trim().isEmpty || product.name.trim().isEmpty) {
      throw const ProductRepositoryException(
        'Product name and SKU are required.',
      );
    }
    if (product.price <= 0 ||
        (product.originalPrice != null && product.originalPrice! <= 0)) {
      throw const ProductRepositoryException(
        'Prices must be greater than zero.',
      );
    }
    final categoryId = await _resolveCategoryId(client, product.category);
    final existingPaths = create
        ? const <String>[]
        : (await client
                  .from('product_images')
                  .select('storage_path')
                  .eq('product_id', product.id))
              .map((row) => row['storage_path']?.toString())
              .whereType<String>()
              .toList();
    final result = await client.rpc(
      'save_product',
      params: {
        'p_product_id': create ? null : product.id,
        'p_sku': product.sku.trim(),
        'p_name': product.name.trim(),
        'p_description': product.description.trim(),
        'p_price_inr': product.price,
        'p_original_price_inr': product.originalPrice,
        'p_category_id': categoryId,
        'p_image_url': product.imageUrl,
        'p_is_active': product.isActive,
        'p_requires_size': product.requiresSize,
        'p_requires_color': product.requiresColor,
        'p_variants': _variantRows(product),
        'p_images': _imageRows(product),
      },
    );
    final id = result.toString();
    final row = await client
        .from('products')
        .select(
          'id,sku,name,description,price_inr,original_price_inr,image_url,is_active,requires_size,requires_color,created_at,category_id,categories(id,name),product_images(image_url,storage_path,sort_order,is_primary),product_variants(id,sku,size,color_name,color_hex,price_override_inr,stock_quantity,is_available)',
        )
        .eq('id', id)
        .single();
    final saved = Product.fromSupabaseRow(Map<String, dynamic>.from(row));
    final remainingPaths = saved.galleryImages
        .map((image) => image.storagePath)
        .whereType<String>()
        .toSet();
    final removed = existingPaths
        .where((path) => !remainingPaths.contains(path))
        .toList();
    if (removed.isNotEmpty) {
      await client.storage.from(productImageBucket).remove(removed);
    }
    return saved;
  }

  Future<ProductGalleryImage> uploadProductImage({
    required String productId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final extension = fileName.split('.').last.toLowerCase();
    if (!supportedProductImageTypes.contains(extension)) {
      throw const ProductRepositoryException(
        'Choose a JPG, PNG or WebP image.',
      );
    }
    if (!isSupportedProductImage(fileName, bytes.length)) {
      throw const ProductRepositoryException(
        'Images must be smaller than 5 MB.',
      );
    }
    final client = _requireClient();
    final suffix =
        Random.secure().nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
    final path =
        '$productId/${DateTime.now().microsecondsSinceEpoch}-$suffix.$extension';
    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    await client.storage
        .from(productImageBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return ProductGalleryImage(
      url: client.storage.from(productImageBucket).getPublicUrl(path),
      storagePath: path,
    );
  }

  Future<void> deleteUploadedImages(List<String> paths) async {
    final client = _client;
    if (client == null || paths.isEmpty) return;
    try {
      await client.storage.from(productImageBucket).remove(paths);
    } catch (_) {}
  }

  Future<void> setVariantStock(
    String variantId,
    int? quantity, {
    bool? isAvailable,
  }) async {
    if (quantity != null && quantity < 0) {
      throw const ProductRepositoryException('Stock cannot be negative.');
    }
    if (quantity == null && isAvailable == null) return;
    await _requireClient().rpc(
      'admin_set_variant_stock',
      params: {
        'p_variant_id': variantId,
        'p_stock_quantity': quantity,
        'p_is_available': isAvailable,
      },
    );
  }

  Future<void> delete(String productId) async {
    final client = _requireClient();
    final storagePaths =
        (await client
                .from('product_images')
                .select('storage_path')
                .eq('product_id', productId))
            .map((row) => row['storage_path']?.toString())
            .whereType<String>()
            .toList();
    final result = await client
        .from('products')
        .delete()
        .eq('id', productId)
        .select('id');
    if (result.isEmpty) {
      throw const ProductRepositoryException(
        'The product was not deleted. Check administrator access and try again.',
      );
    }
    if (storagePaths.isNotEmpty) {
      await client.storage.from(productImageBucket).remove(storagePaths);
    }
  }

  static List<Map<String, dynamic>> _variantRows(Product product) {
    if (product.variants.isNotEmpty) {
      return [
        for (final variant in product.variants)
          {
            'id': variant.id,
            'sku': variant.sku,
            'size': variant.size,
            'color_name': variant.colorName,
            'color_hex': _hex(variant.colorValue),
            'price_override_inr': variant.priceOverride,
            'stock_quantity': variant.stockQuantity,
            'is_available': variant.isAvailable,
          },
      ];
    }
    final combinations = [
      for (final size in product.requiresSize ? product.sizes : ['One Size'])
        for (final color
            in product.requiresColor
                ? product.colors
                : const [ProductColor('Standard', 0xFFF5F1EA)])
          (size: size, color: color),
    ];
    if (combinations.isEmpty) return const [];
    final baseStock = product.stockQuantity ~/ combinations.length;
    final remainder = product.stockQuantity % combinations.length;
    return [
      for (var index = 0; index < combinations.length; index++)
        {
          'sku': '${product.sku}-${index + 1}',
          'size': combinations[index].size,
          'color_name': combinations[index].color.name,
          'color_hex': _hex(combinations[index].color.value),
          'price_override_inr': null,
          'stock_quantity': baseStock + (index < remainder ? 1 : 0),
          'is_available': true,
        },
    ];
  }

  static List<Map<String, dynamic>> _imageRows(Product product) {
    final images = product.galleryImages;
    if (images.isEmpty) {
      return product.galleryImageUrls.isEmpty
          ? [
              {
                'image_url': product.imageUrl,
                'storage_path': null,
                'sort_order': 0,
                'is_primary': true,
              },
            ]
          : [
              for (
                var index = 0;
                index < product.galleryImageUrls.length;
                index++
              )
                {
                  'image_url': product.galleryImageUrls[index],
                  'storage_path': null,
                  'sort_order': index,
                  'is_primary':
                      product.galleryImageUrls[index] == product.imageUrl,
                },
            ];
    }
    return [
      for (var index = 0; index < images.length; index++)
        {
          'image_url': images[index].url,
          'storage_path': images[index].storagePath,
          'sort_order': index,
          'is_primary': images[index].url == product.imageUrl,
        },
    ];
  }

  Future<String> _resolveCategoryId(SupabaseClient client, String name) async {
    final slug = _slugify(name);
    final existing = await client
        .from('categories')
        .select('id')
        .eq('slug', slug)
        .maybeSingle();
    if (existing != null) return existing['id'].toString();
    try {
      final inserted = await client
          .from('categories')
          .insert({'name': name, 'slug': slug})
          .select('id')
          .single();
      return inserted['id'].toString();
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        final raced = await client
            .from('categories')
            .select('id')
            .eq('slug', slug)
            .single();
        return raced['id'].toString();
      }
      rethrow;
    }
  }

  String _slugify(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const ProductRepositoryException(
        'Supabase is not configured. Database operations are unavailable.',
      );
    }
    return client;
  }
}
