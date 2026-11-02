import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/norve_theme.dart';
import '../products/product.dart';
import '../products/product_catalog_provider.dart';
import '../products/product_repository.dart';
import '../products/widgets/product_image.dart';

class AdminProductFormScreen extends ConsumerStatefulWidget {
  const AdminProductFormScreen({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<AdminProductFormScreen> createState() =>
      _AdminProductFormScreenState();
}

class _AdminProductFormScreenState
    extends ConsumerState<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _category;
  late final TextEditingController _imageUrl;
  late final TextEditingController _sizes;
  late final TextEditingController _colors;
  late final TextEditingController _stock;
  late final TextEditingController _salePrice;
  late List<_AdminImage> _images;
  int _primaryImageIndex = 0;
  int? _uploadingImageIndex;
  bool _requiresSize = true;
  bool _requiresColor = true;
  final Map<String, String> _variantSkus = {};
  final Map<String, String> _variantPriceOverrides = {};
  Product? _existingProduct;
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final id = widget.productId;
    if (id != null) {
      final matches = ref
          .read(productCatalogProvider)
          .where((product) => product.id == id);
      if (matches.isNotEmpty) _existingProduct = matches.first;
    }
    final product = _existingProduct;
    _name = TextEditingController(text: product?.name ?? '');
    _sku = TextEditingController(text: product?.sku ?? '');
    _description = TextEditingController(text: product?.description ?? '');
    _price = TextEditingController(text: product?.price.toString() ?? '');
    _category = TextEditingController(text: product?.category ?? '');
    _imageUrl = TextEditingController(text: product?.imageUrl ?? '');
    _sizes = TextEditingController(
      text: product?.sizes.join(', ') ?? 'S, M, L, XL',
    );
    _colors = TextEditingController(
      text:
          product?.colors.map((color) => color.name).join(', ') ??
          'Chalk, Charcoal',
    );
    _stock = TextEditingController(
      text: product?.stockQuantity.toString() ?? '0',
    );
    for (final variant in product?.variants ?? const <ProductVariant>[]) {
      final key = variant.id ?? '${variant.size}|${variant.colorName}';
      _variantSkus[key] = variant.sku;
      _variantPriceOverrides[key] = variant.priceOverride?.toString() ?? '';
    }
    _salePrice = TextEditingController(
      text: product?.originalPrice?.toString() ?? '',
    );
    _requiresSize = product?.requiresSize ?? true;
    _requiresColor = product?.requiresColor ?? true;
    final images = product?.galleryImages ?? const <ProductGalleryImage>[];
    _images = images.isNotEmpty
        ? images.map(_AdminImage.saved).toList()
        : (product?.galleryImageUrls.isNotEmpty == true
              ? product!.galleryImageUrls
                    .map(
                      (url) => _AdminImage.saved(ProductGalleryImage(url: url)),
                    )
                    .toList()
              : product == null
              ? []
              : [
                  _AdminImage.saved(ProductGalleryImage(url: product.imageUrl)),
                ]);
    final primaryIndex = _images.indexWhere(
      (image) => image.savedImage?.url == product?.imageUrl,
    );
    _primaryImageIndex = primaryIndex < 0 ? 0 : primaryIndex;
    _isActive = product?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _description.dispose();
    _price.dispose();
    _category.dispose();
    _imageUrl.dispose();
    _sizes.dispose();
    _colors.dispose();
    _stock.dispose();
    _salePrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.productId != null;
    final categories = ref.watch(productCategoriesProvider);
    final categoryList = categories.asData?.value ?? const <ProductCategory>[];
    final categoryNames = categoryList.map((item) => item.name).toList();
    final selectedCategory = categoryNames.contains(_category.text)
        ? _category.text
        : categoryNames.firstOrNull;
    if (isEditing && _existingProduct == null) {
      return const Center(child: Text('This product is no longer available.'));
    }
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: ListView(
              key: const ValueKey('product-form-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
              children: [
                Text(
                  isEditing ? 'Edit product' : 'Add product',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Changes are shared with the customer catalogue and inventory.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: NorveColors.muted),
                ),
                const SizedBox(height: 22),
                _textField(_name, 'Product name', key: 'product-name'),
                _textField(_sku, 'Product SKU', key: 'product-sku'),
                _textField(
                  _description,
                  'Description',
                  key: 'product-description',
                  maxLines: 3,
                ),
                _textField(
                  _price,
                  'Price (INR)',
                  key: 'product-price',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    final price = int.tryParse(value ?? '');
                    if (price == null || price <= 0) {
                      return 'Enter a price greater than zero.';
                    }
                    return null;
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 13),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('product-category-$selectedCategory'),
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: categoryList
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.name,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) _category.text = value;
                    },
                    validator: (value) => value == null || value.isEmpty
                        ? 'Create or select a category.'
                        : null,
                  ),
                ),
                _textField(
                  _imageUrl,
                  'External image URL (optional when uploading)',
                  key: 'product-image-url',
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (_images.isNotEmpty && (value ?? '').trim().isEmpty) {
                      return null;
                    }
                    final uri = Uri.tryParse((value ?? '').trim());
                    if (uri == null ||
                        !{'http', 'https'}.contains(uri.scheme) ||
                        uri.host.isEmpty) {
                      return 'Enter a valid http or https image URL.';
                    }
                    return null;
                  },
                ),
                _textField(
                  _salePrice,
                  'Regular price (optional)',
                  key: 'product-sale-price',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    final regular = int.tryParse(value);
                    final sale = int.tryParse(_price.text);
                    if (regular == null || sale == null || regular <= sale) {
                      return 'Regular price must be greater than the current price.';
                    }
                    return null;
                  },
                ),
                SwitchListTile.adaptive(
                  key: const ValueKey('product-requires-size'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Customer selects a size'),
                  value: _requiresSize,
                  onChanged: (value) => setState(() => _requiresSize = value),
                ),
                if (_requiresSize)
                  _textField(
                    _sizes,
                    'Available sizes',
                    key: 'product-sizes',
                    helperText: 'Separate values with commas',
                  ),
                SwitchListTile.adaptive(
                  key: const ValueKey('product-requires-color'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Customer selects a colour'),
                  value: _requiresColor,
                  onChanged: (value) => setState(() => _requiresColor = value),
                ),
                if (_requiresColor)
                  _textField(
                    _colors,
                    'Available colours',
                    key: 'product-colors',
                    helperText: 'Separate colour names with commas',
                  ),
                if (_existingProduct == null)
                  _textField(
                    _stock,
                    'Total stock across variants',
                    key: 'product-stock',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final stock = int.tryParse(value ?? '');
                      return stock == null || stock < 0
                          ? 'Stock must be zero or more.'
                          : null;
                    },
                  ),
                if (_existingProduct != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      'Edit individual variant stock in Admin → Inventory.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: NorveColors.muted),
                    ),
                  ),
                if (_existingProduct?.variants.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Variant details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final variant in _existingProduct!.variants)
                    _variantEditor(context, variant),
                ],
                _buildImageManager(context),
                SwitchListTile.adaptive(
                  key: const ValueKey('product-active'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active in customer catalogue'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const ValueKey('save-product'),
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: NorveColors.charcoal,
                    foregroundColor: NorveColors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEditing ? 'Save changes' : 'Create product'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    required String key,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? helperText,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator:
          validator ??
          (value) => (value == null || value.trim().isEmpty)
              ? 'This field is required.'
              : null,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1,
      ),
    ),
  );

  Widget _buildImageManager(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Product images', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Select a primary image and drag to reorder the gallery. JPG, PNG or WebP up to 5 MB each.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: NorveColors.muted),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const ValueKey('pick-product-images'),
          onPressed: _uploadingImageIndex == null ? _pickImages : null,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Add images'),
        ),
        if (_uploadingImageIndex != null) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _images.isEmpty
                ? null
                : (_uploadingImageIndex! + 1) / _images.length,
          ),
          const SizedBox(height: 4),
          Text(
            'Uploading image ${_uploadingImageIndex! + 1} of ${_images.length}…',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_images.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Add at least one image.'),
          )
        else
          ReorderableListView.builder(
            key: const ValueKey('product-image-order'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _images.length,
            onReorderItem: (oldIndex, newIndex) => setState(() {
              final image = _images.removeAt(oldIndex);
              _images.insert(newIndex, image);
              if (_primaryImageIndex == oldIndex) {
                _primaryImageIndex = newIndex;
              } else if (oldIndex < _primaryImageIndex &&
                  newIndex >= _primaryImageIndex) {
                _primaryImageIndex--;
              } else if (oldIndex > _primaryImageIndex &&
                  newIndex <= _primaryImageIndex) {
                _primaryImageIndex++;
              }
            }),
            itemBuilder: (context, index) {
              final item = _images[index];
              return ListTile(
                key: ValueKey('product-image-$index-${item.label}'),
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 48,
                  height: 54,
                  child: item.savedImage != null
                      ? ProductImage(url: item.savedImage!.url)
                      : Image.memory(item.bytes!, fit: BoxFit.cover),
                ),
                title: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  index == _primaryImageIndex
                      ? 'Primary image'
                      : 'Gallery image',
                ),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: index == _primaryImageIndex
                          ? 'Primary image'
                          : 'Set as primary image',
                      onPressed: () =>
                          setState(() => _primaryImageIndex = index),
                      icon: Icon(
                        index == _primaryImageIndex
                            ? Icons.star
                            : Icons.star_border,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove image',
                      onPressed: _uploadingImageIndex == null
                          ? () => setState(() {
                              _images.removeAt(index);
                              if (_images.isEmpty) {
                                _primaryImageIndex = 0;
                              } else if (_primaryImageIndex >= _images.length) {
                                _primaryImageIndex = _images.length - 1;
                              } else if (index < _primaryImageIndex) {
                                _primaryImageIndex--;
                              }
                            })
                          : null,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    ),
  );

  Future<void> _pickImages() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedProductImageTypes.toList(),
      );
      if (files.isEmpty || !mounted) return;
      final additions = <_AdminImage>[];
      for (final file in files) {
        final extension = file.extension?.toLowerCase() ?? '';
        final size = file.lengthSync() ?? await file.length() ?? 0;
        if (!mounted) return;
        if (!supportedProductImageTypes.contains(extension) ||
            size > maxProductImageBytes ||
            size == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${file.name} is unsupported or exceeds 5 MB.'),
            ),
          );
          continue;
        }
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        if (bytes.length > maxProductImageBytes) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${file.name} exceeds 5 MB.')));
          continue;
        }
        additions.add(_AdminImage.picked(file.name, bytes));
      }
      if (additions.isNotEmpty) {
        setState(() {
          if (_images.isEmpty) _primaryImageIndex = 0;
          _images.addAll(additions);
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Images could not be selected: $error')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _name.text.trim();
    final sizes = _sizes.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    final colorNames = _colors.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    if ((_requiresSize && sizes.isEmpty) ||
        (_requiresColor && colorNames.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one option for each enabled variant dimension.',
          ),
        ),
      );
      return;
    }
    if (_images.isEmpty && _imageUrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product image.')),
      );
      return;
    }
    final existing = _existingProduct;
    final category = _category.text.trim().isNotEmpty
        ? _category.text.trim()
        : ref.read(productCategoriesProvider).asData?.value.firstOrNull?.name ??
              '';
    final optionsSizes = _requiresSize ? sizes : ['One Size'];
    final optionsColors = _requiresColor
        ? colorNames.map(_productColor).toList()
        : const [ProductColor('Standard', 0xFFF5F1EA)];
    final combinations = [
      for (final size in optionsSizes)
        for (final color in optionsColors) (size: size, color: color),
    ];
    final previousVariants = existing?.variants ?? const <ProductVariant>[];
    final totalStock = int.tryParse(_stock.text) ?? 0;
    final baseStock = combinations.isEmpty
        ? 0
        : totalStock ~/ combinations.length;
    final remainder = combinations.isEmpty
        ? 0
        : totalStock % combinations.length;
    final variants = <ProductVariant>[];
    for (var index = 0; index < combinations.length; index++) {
      final combination = combinations[index];
      ProductVariant? previous;
      for (final variant in previousVariants) {
        if (variant.size == combination.size &&
            variant.colorName == combination.color.name) {
          previous = variant;
          break;
        }
      }
      final variantKey =
          previous?.id ?? '${combination.size}|${combination.color.name}';
      final sku = _variantSkus[variantKey]?.trim();
      final overrideText = _variantPriceOverrides[variantKey]?.trim() ?? '';
      final priceOverride = overrideText.isEmpty
          ? null
          : int.tryParse(overrideText);
      if (overrideText.isNotEmpty &&
          (priceOverride == null || priceOverride < 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Variant prices must be zero or more.')),
        );
        setState(() => _saving = false);
        return;
      }
      variants.add(
        previous != null
            ? ProductVariant(
                id: previous.id,
                sku: sku?.isNotEmpty == true ? sku! : previous.sku,
                size: previous.size,
                colorName: previous.colorName,
                colorValue: previous.colorValue,
                stockQuantity: previous.stockQuantity,
                priceOverride: priceOverride,
                isAvailable: previous.isAvailable,
              )
            : ProductVariant(
                sku:
                    '${_sku.text.trim()}-${(index + 1).toString().padLeft(2, '0')}',
                size: combination.size,
                colorName: combination.color.name,
                colorValue: combination.color.value,
                stockQuantity: previousVariants.isEmpty
                    ? baseStock + (index < remainder ? 1 : 0)
                    : 0,
              ),
      );
    }
    final savedImages = <ProductGalleryImage>[];
    setState(() => _saving = true);
    try {
      for (var index = 0; index < _images.length; index++) {
        setState(() => _uploadingImageIndex = index);
        final image = _images[index];
        if (image.savedImage != null) {
          savedImages.add(image.savedImage!);
        } else {
          savedImages.add(
            await ref
                .read(productRepositoryProvider)
                .uploadProductImage(
                  productId:
                      existing?.id ??
                      'new-${DateTime.now().microsecondsSinceEpoch}',
                  fileName: image.label,
                  bytes: image.bytes!,
                ),
          );
        }
      }
      if (savedImages.isEmpty) {
        savedImages.add(
          ProductGalleryImage(url: _imageUrl.text.trim(), isPrimary: true),
        );
      }
      final safePrimaryIndex = _primaryImageIndex.clamp(
        0,
        savedImages.length - 1,
      );
      final primaryUrl = savedImages[safePrimaryIndex].url;
      final stockTotal = variants.fold<int>(
        0,
        (sum, variant) => sum + variant.stockQuantity,
      );
      final product = Product(
        id: existing?.id ?? 'product-${DateTime.now().microsecondsSinceEpoch}',
        sku: _sku.text.trim(),
        name: name,
        description: _description.text.trim(),
        price: int.parse(_price.text),
        originalPrice: _salePrice.text.trim().isEmpty
            ? null
            : int.parse(_salePrice.text),
        category: category,
        imageUrl: primaryUrl,
        galleryImageUrls: savedImages.map((image) => image.url).toList(),
        galleryImages: savedImages,
        sizes: _requiresSize ? sizes : const [],
        colors: _requiresColor
            ? colorNames.map(_productColor).toList()
            : const [],
        stockQuantity: stockTotal,
        isActive: _isActive,
        requiresSize: _requiresSize,
        requiresColor: _requiresColor,
        variants: variants,
      );
      await ref
          .read(productCatalogProvider.notifier)
          .save(product, create: existing == null);
      if (mounted) context.pop();
    } catch (error) {
      if (existing == null && savedImages.isNotEmpty) {
        final orphanedPaths = savedImages
            .map((img) => img.storagePath)
            .whereType<String>()
            .toList();
        if (orphanedPaths.isNotEmpty) {
          try {
            await ref
                .read(productRepositoryProvider)
                .deleteUploadedImages(orphanedPaths);
          } catch (_) {}
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadingImageIndex = null;
        });
      }
    }
  }

  Widget _variantEditor(BuildContext context, ProductVariant variant) {
    final key = variant.id ?? '${variant.size}|${variant.colorName}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${variant.size} · ${variant.colorName}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('variant-sku-$key'),
                  initialValue: _variantSkus[key] ?? variant.sku,
                  decoration: const InputDecoration(labelText: 'Variant SKU'),
                  onChanged: (value) => _variantSkus[key] = value,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: ValueKey('variant-price-$key'),
                  initialValue:
                      _variantPriceOverrides[key] ??
                      variant.priceOverride?.toString() ??
                      '',
                  decoration: const InputDecoration(
                    labelText: 'Price override (optional)',
                    prefixText: '₹ ',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) => _variantPriceOverrides[key] = value,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ProductColor _productColor(String name) {
    final key = name.toLowerCase();
    final value = switch (key) {
      'chalk' || 'ivory' => 0xFFF5F1EA,
      'white' => 0xFFFFFFFF,
      'charcoal' => 0xFF24211E,
      'olive' || 'moss' => 0xFF77715F,
      'natural' || 'oatmeal' => 0xFFD8CBB7,
      'stone' || 'tan' => 0xFFC9BEAC,
      'slate' || 'grey' || 'gray' => 0xFF777B7C,
      'navy' => 0xFF46494C,
      _ => 0xFF77716A,
    };
    return ProductColor(name, value);
  }
}

class _AdminImage {
  const _AdminImage._({this.savedImage, this.bytes, required this.label});

  factory _AdminImage.saved(ProductGalleryImage image) =>
      _AdminImage._(savedImage: image, label: image.url);

  factory _AdminImage.picked(String name, Uint8List bytes) =>
      _AdminImage._(bytes: bytes, label: name);

  final ProductGalleryImage? savedImage;
  final Uint8List? bytes;
  final String label;
}
