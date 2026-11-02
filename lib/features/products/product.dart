class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.description,
    required this.sizes,
    required this.colors,
    this.sku = '',
    this.requiresSize = true,
    this.requiresColor = true,
    this.stockQuantity = 20,
    this.isActive = true,
    this.originalPrice,
    this.galleryImageUrls = const [],
    this.galleryImages = const [],
    this.variants = const [],
    this.createdAt,
    this.categoryId = '',
  });

  final String id;
  final String name;
  final int price;
  final String imageUrl;
  final String category;
  final String categoryId;
  final String description;
  final String sku;
  final bool requiresSize;
  final bool requiresColor;
  final int? originalPrice;
  final List<String> sizes;
  final List<ProductColor> colors;
  final List<String> galleryImageUrls;
  final List<ProductGalleryImage> galleryImages;
  final int stockQuantity;
  final bool isActive;
  final List<ProductVariant> variants;
  final DateTime? createdAt;

  bool get isPurchasable =>
      isActive &&
      (variants.isEmpty
          ? stockQuantity > 0
          : variants.any(
              (variant) => variant.isAvailable && variant.stockQuantity > 0,
            ));

  String get formattedPrice => formatInr(price);

  Product copyWith({
    String? id,
    String? name,
    int? price,
    String? imageUrl,
    String? category,
    String? description,
    int? originalPrice,
    List<String>? sizes,
    List<ProductColor>? colors,
    List<String>? galleryImageUrls,
    List<ProductGalleryImage>? galleryImages,
    int? stockQuantity,
    bool? isActive,
    List<ProductVariant>? variants,
    String? sku,
    bool? requiresSize,
    bool? requiresColor,
    DateTime? createdAt,
    String? categoryId,
  }) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    price: price ?? this.price,
    imageUrl: imageUrl ?? this.imageUrl,
    category: category ?? this.category,
    description: description ?? this.description,
    originalPrice: originalPrice ?? this.originalPrice,
    sizes: sizes ?? this.sizes,
    colors: colors ?? this.colors,
    galleryImageUrls: galleryImageUrls ?? this.galleryImageUrls,
    galleryImages: galleryImages ?? this.galleryImages,
    stockQuantity: stockQuantity ?? this.stockQuantity,
    isActive: isActive ?? this.isActive,
    variants: variants ?? this.variants,
    sku: sku ?? this.sku,
    requiresSize: requiresSize ?? this.requiresSize,
    requiresColor: requiresColor ?? this.requiresColor,
    createdAt: createdAt ?? this.createdAt,
    categoryId: categoryId ?? this.categoryId,
  );

  factory Product.fromSupabaseRow(Map<String, dynamic> row) {
    final relation = row['categories'];
    final categoryRow = relation is List && relation.isNotEmpty
        ? relation.first
        : relation;
    final categoryName = categoryRow is Map
        ? categoryRow['name']?.toString() ?? ''
        : row['category']?.toString() ?? '';
    final categoryId = categoryRow is Map
        ? categoryRow['id']?.toString() ?? ''
        : row['category_id']?.toString() ?? '';
    final variantRows = row['product_variants'] is List
        ? row['product_variants'] as List
        : const [];
    final variants = variantRows
        .whereType<Map>()
        .map(
          (variant) => ProductVariant.fromSupabaseRow(
            Map<String, dynamic>.from(variant),
          ),
        )
        .toList();
    final sizes = variants
        .map((variant) => variant.size)
        .where((size) => size.isNotEmpty && size != 'One Size')
        .toSet()
        .toList();
    final colors = <String, ProductColor>{};
    for (final variant in variants) {
      if (variant.colorName.isNotEmpty && variant.colorName != 'Standard') {
        colors.putIfAbsent(
          variant.colorName,
          () => ProductColor(variant.colorName, variant.colorValue),
        );
      }
    }
    final priceValue = row['price_inr'];
    final priceNumber = priceValue is num
        ? priceValue
        : num.parse(priceValue.toString());
    if (priceNumber != priceNumber.roundToDouble()) {
      throw const FormatException('Product prices must use whole INR amounts.');
    }
    final originalValue = row['original_price_inr'];
    final originalPrice = originalValue == null
        ? null
        : (originalValue is num
                  ? originalValue
                  : num.parse(originalValue.toString()))
              .toInt();
    final imageUrl = row['image_url']?.toString() ?? '';
    final imageRows = row['product_images'] is List
        ? (row['product_images'] as List).whereType<Map>().toList()
        : <Map>[];
    imageRows.sort(
      (a, b) => ((a['sort_order'] as num?)?.toInt() ?? 0).compareTo(
        (b['sort_order'] as num?)?.toInt() ?? 0,
      ),
    );
    final galleryImages = imageRows
        .map(
          (image) => ProductGalleryImage(
            url: image['image_url']?.toString() ?? '',
            storagePath: image['storage_path']?.toString(),
            sortOrder: (image['sort_order'] as num?)?.toInt() ?? 0,
            isPrimary: image['is_primary'] == true,
          ),
        )
        .toList();
    return Product(
      id: row['id'].toString(),
      name: row['name']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      sku: row['sku']?.toString() ?? '',
      requiresSize: row['requires_size'] != false,
      requiresColor: row['requires_color'] != false,
      price: priceNumber.toInt(),
      originalPrice: originalPrice,
      category: categoryName,
      categoryId: categoryId,
      imageUrl: imageUrl,
      galleryImageUrls: galleryImages.isNotEmpty
          ? galleryImages.map((image) => image.url).toList()
          : imageUrl.isEmpty
          ? const []
          : [imageUrl],
      galleryImages: galleryImages,
      sizes: sizes,
      colors: colors.values.toList(),
      variants: variants,
      stockQuantity: variants.fold<int>(
        0,
        (sum, variant) => sum + variant.stockQuantity,
      ),
      isActive: row['is_active'] == true,
    );
  }
}

class ProductGalleryImage {
  const ProductGalleryImage({
    required this.url,
    this.storagePath,
    this.sortOrder = 0,
    this.isPrimary = false,
  });

  final String url;
  final String? storagePath;
  final int sortOrder;
  final bool isPrimary;
}

class ProductVariant {
  const ProductVariant({
    required this.size,
    required this.colorName,
    required this.colorValue,
    required this.stockQuantity,
    this.id,
    this.sku = '',
    this.priceOverride,
    this.isAvailable = true,
  });

  final String? id;
  final String sku;
  final int? priceOverride;
  final bool isAvailable;
  final String size;
  final String colorName;
  final int colorValue;
  final int stockQuantity;

  factory ProductVariant.fromSupabaseRow(Map<String, dynamic> row) {
    final rawHex = row['color_hex']?.toString() ?? '#77716A';
    final cleanHex = rawHex.replaceFirst('#', '');
    final parsedHex = int.tryParse(cleanHex, radix: 16) ?? 0x77716A;
    return ProductVariant(
      id: row['id']?.toString(),
      sku: row['sku']?.toString() ?? '',
      priceOverride: row['price_override_inr'] == null
          ? null
          : (row['price_override_inr'] as num).toInt(),
      isAvailable: row['is_available'] != false,
      size: row['size']?.toString() ?? '',
      colorName: row['color_name']?.toString() ?? '',
      colorValue: 0xFF000000 | parsedHex,
      stockQuantity: (row['stock_quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

String formatInr(int value) {
  final digits = value.toString();
  if (digits.length <= 3) return '₹$digits';
  final lastThree = digits.substring(digits.length - 3);
  var prefix = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (prefix.length > 2) {
    groups.insert(0, prefix.substring(prefix.length - 2));
    prefix = prefix.substring(0, prefix.length - 2);
  }
  if (prefix.isNotEmpty) groups.insert(0, prefix);
  return '₹${groups.join(',')},$lastThree';
}

String productVariantLabel(String size, String color) => [
  if (size.isNotEmpty && size != 'One Size') size,
  if (color.isNotEmpty && color != 'Standard') color,
].join(' · ');

class ProductColor {
  const ProductColor(this.name, this.value);

  final String name;
  final int value;
}

const _teeColors = [
  ProductColor('Chalk', 0xFFF5F1EA),
  ProductColor('Charcoal', 0xFF24211E),
  ProductColor('Olive', 0xFF77715F),
];
const _shirtColors = [
  ProductColor('Natural', 0xFFD9CDBB),
  ProductColor('White', 0xFFFFFFFF),
  ProductColor('Slate', 0xFF777B7C),
];
const _knitColors = [
  ProductColor('Oatmeal', 0xFFD8CBB7),
  ProductColor('Charcoal', 0xFF24211E),
  ProductColor('Moss', 0xFF77715F),
];
const _trouserColors = [
  ProductColor('Stone', 0xFFC9BEAC),
  ProductColor('Charcoal', 0xFF24211E),
  ProductColor('Navy', 0xFF46494C),
];
const _sizes = ['S', 'M', 'L', 'XL'];

const products = <Product>[
  Product(
    id: 'cotton-tee',
    name: 'Essential Cotton Tee',
    price: 799,
    originalPrice: 999,
    category: 'T-shirts',
    description: 'A considered everyday staple cut from soft, breathable cotton. Designed with a clean crew neckline and an easy, timeless fit.',
    imageUrl: 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=900&q=85',
    galleryImageUrls: [
      'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1200&q=90',
      'https://images.unsplash.com/photo-1503341504253-dff4815485f1?auto=format&fit=crop&w=1200&q=90',
    ],
    sizes: _sizes,
    colors: _teeColors,
    stockQuantity: 3,
  ),
  Product(
    id: 'linen-shirt',
    name: 'Relaxed Linen Shirt',
    price: 1499,
    category: 'Shirts',
    description: 'An airy linen blend shirt with a relaxed drape. Made for warm days, easy layering, and the quiet rhythm of everyday dressing.',
    imageUrl: 'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?auto=format&fit=crop&w=900&q=85',
    galleryImageUrls: [
      'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?auto=format&fit=crop&w=1200&q=90',
      'https://images.unsplash.com/photo-1603252109303-2751441dd157?auto=format&fit=crop&w=1200&q=90',
    ],
    sizes: _sizes,
    colors: _shirtColors,
    stockQuantity: 12,
  ),
  Product(
    id: 'knit-hoodie',
    name: 'Everyday Knit Hoodie',
    price: 1899,
    category: 'Knitwear',
    description: 'A soft, mid-weight knit hoodie that brings a refined feel to a familiar layer. Finished with a relaxed shape and considered details.',
    imageUrl: 'https://images.unsplash.com/photo-1556821840-3a63f95609a7?auto=format&fit=crop&w=900&q=85',
    galleryImageUrls: [
      'https://images.unsplash.com/photo-1556821840-3a63f95609a7?auto=format&fit=crop&w=1200&q=90',
      'https://images.unsplash.com/photo-1578681994506-b8f463449011?auto=format&fit=crop&w=1200&q=90',
    ],
    sizes: _sizes,
    colors: _knitColors,
    stockQuantity: 2,
  ),
  Product(
    id: 'straight-trousers',
    name: 'Tailored Straight Trousers',
    price: 1699,
    category: 'Trousers',
    description: 'A clean straight-leg silhouette with a comfortable mid rise. An understated foundation for effortless weekday and weekend dressing.',
    imageUrl: 'https://images.unsplash.com/photo-1473966968600-fa801b869a1a?auto=format&fit=crop&w=900&q=85',
    galleryImageUrls: [
      'https://images.unsplash.com/photo-1473966968600-fa801b869a1a?auto=format&fit=crop&w=1200&q=90',
      'https://images.unsplash.com/photo-1517438476312-10d79c077509?auto=format&fit=crop&w=1200&q=90',
    ],
    sizes: _sizes,
    colors: _trouserColors,
    stockQuantity: 8,
  ),
  Product(
    id: 'oversized-tee',
    name: 'Classic Oversized Tee',
    price: 899,
    category: 'T-shirts',
    description: 'A generous silhouette in soft cotton jersey. An easy, versatile tee with a little more room to move.',
    imageUrl: 'https://images.unsplash.com/photo-1503341504253-dff4815485f1?auto=format&fit=crop&w=900&q=85',
    galleryImageUrls: [
      'https://images.unsplash.com/photo-1503341504253-dff4815485f1?auto=format&fit=crop&w=1200&q=90',
      'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1200&q=90',
    ],
    sizes: _sizes,
    colors: _teeColors,
    stockQuantity: 5,
  ),
  Product(
    id: 'crewneck-sweatshirt',
    name: 'Minimal Crewneck Sweatshirt',
    price: 1599,
    category: 'Knitwear',
    description: 'A soft brushed cotton sweatshirt with a minimal crew neckline. A dependable layer in a refined, relaxed fit.',
    imageUrl: 'https://images.unsplash.com/photo-1578681994506-b8f463449011?auto=format&fit=crop&w=900&q=85',
    galleryImageUrls: [
      'https://images.unsplash.com/photo-1578681994506-b8f463449011?auto=format&fit=crop&w=1200&q=90',
      'https://images.unsplash.com/photo-1556821840-3a63f95609a7?auto=format&fit=crop&w=1200&q=90',
    ],
    sizes: _sizes,
    colors: _knitColors,
    stockQuantity: 1,
  ),
];
