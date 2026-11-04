import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/supabase/supabase_providers.dart';
import '../products/product.dart';
import '../products/product_catalog_provider.dart';
import '../products/product_repository.dart';
import '../products/widgets/catalog_state_notice.dart';
import '../products/widgets/product_image.dart';
import 'widgets/admin_widgets.dart';

/// Redesigned NORVÉ Admin Product Details & Form Screen.
///
/// Implements a luxury two-column editorial product management experience
/// inspired by the Wolfpixel Product Details visual reference for both:
/// - Add Product (`/admin/products/new`)
/// - Edit Product (`/admin/products/:productId/edit`)
///
/// Architecture:
/// - Left column (approx. 40%): Large primary image preview, interactive thumbnail
///   gallery, primary image selector, image uploader, and reordering.
/// - Right column (approx. 60%): Structured cards for Basic Info, Pricing,
///   External Image Source, Variants & Options, Inventory, and Catalogue Visibility.
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
  int _selectedPreviewIndex = 0;
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
    _selectedPreviewIndex = _primaryImageIndex;
    _isActive = product?.isActive ?? true;

    _imageUrl.addListener(_onFormStateChanged);
    _price.addListener(_onFormStateChanged);
    _salePrice.addListener(_onFormStateChanged);
    _sizes.addListener(_onFormStateChanged);
    _colors.addListener(_onFormStateChanged);
    _stock.addListener(_onFormStateChanged);
  }

  void _onFormStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _imageUrl.removeListener(_onFormStateChanged);
    _price.removeListener(_onFormStateChanged);
    _salePrice.removeListener(_onFormStateChanged);
    _sizes.removeListener(_onFormStateChanged);
    _colors.removeListener(_onFormStateChanged);
    _stock.removeListener(_onFormStateChanged);
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
      return Scaffold(
        backgroundColor: AdminColors.ivory,
        body: Center(
          child: AdminEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Product Not Found',
            message:
                'This product could not be located in the boutique catalogue.',
            actionLabel: 'Return to Products',
            onAction: () => context.go('/admin/products'),
          ),
        ),
      );
    }

    if (isEditing) {
      return _buildEditLayout(context, selectedCategory, categoryList);
    }

    return _buildCreateLayout(context, selectedCategory, categoryList);
  }

  // ===========================================================================
  // REDESIGNED EDIT LAYOUT (Wolfpixel Two-Column Architecture)
  // ===========================================================================
  Widget _buildEditLayout(
    BuildContext context,
    String? selectedCategory,
    List<ProductCategory> categoryList,
  ) {
    return Scaffold(
      backgroundColor: AdminColors.ivory,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            key: const ValueKey('product-edit-scroll'),
            slivers: [
              const SliverToBoxAdapter(child: CatalogStateNotice()),
              SliverToBoxAdapter(
                child: AdminPageHeader(
                  breadcrumbs: InkWell(
                    onTap: () => context.go('/admin/products'),
                    borderRadius: AdminRadii.radiusXs,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.arrow_back,
                            size: 14,
                            color: AdminColors.muted,
                          ),
                          SizedBox(width: 6),
                          Text('Products', style: AdminTypography.caption),
                        ],
                      ),
                    ),
                  ),
                  title: 'Edit Product',
                  subtitle:
                      'Manage product information, pricing and availability.',
                  actions: [
                    AdminButton.secondary(
                      label: 'Cancel',
                      onPressed: () => context.go('/admin/products'),
                    ),
                    AdminButton.primary(
                      key: const ValueKey('save-product'),
                      label: 'Save Changes',
                      icon: const Icon(Icons.check, size: 16),
                      isLoading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 960;
                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column (Gallery) ~40%
                            Expanded(
                              flex: 4,
                              child: _buildGalleryColumn(context),
                            ),
                            const SizedBox(width: 24),
                            // Right Column (Structured Information Cards) ~60%
                            Expanded(
                              flex: 6,
                              child: _buildInformationColumn(
                                context,
                                selectedCategory,
                                categoryList,
                              ),
                            ),
                          ],
                        );
                      }

                      // Stacked Single Column on Tablet / Mobile
                      return Column(
                        children: [
                          _buildGalleryColumn(context),
                          const SizedBox(height: 24),
                          _buildInformationColumn(
                            context,
                            selectedCategory,
                            categoryList,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Left Column — Product Image Gallery (Wolfpixel Inspired)
  // ---------------------------------------------------------------------------
  Widget _buildGalleryColumn(BuildContext context) {
    final hasImages = _images.isNotEmpty;
    final safePreviewIndex =
        hasImages ? _selectedPreviewIndex.clamp(0, _images.length - 1) : 0;
    final currentImage = hasImages ? _images[safePreviewIndex] : null;
    final isPrimarySelected =
        hasImages && safePreviewIndex == _primaryImageIndex;

    return AdminCard(
      title: 'Product Gallery',
      subtitle: 'Primary visual presentation and boutique catalogue assets',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Large Primary Image Preview
          Container(
            width: double.infinity,
            height: 380,
            decoration: BoxDecoration(
              color: AdminColors.surfaceSubtle,
              borderRadius: AdminRadii.radiusSm,
              border: Border.all(color: AdminColors.lineSubtle),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (currentImage != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: currentImage.savedImage != null
                          ? ProductImage(
                              url: currentImage.savedImage!.url,
                              fit: BoxFit.contain,
                            )
                          : Image.memory(
                              currentImage.bytes!,
                              fit: BoxFit.contain,
                            ),
                    ),
                  )
                else if (_imageUrl.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ProductImage(
                        url: _imageUrl.text.trim(),
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: AdminColors.white,
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(
                                AdminBorders.sideSubtle,
                              ),
                            ),
                            child: const Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 28,
                              color: AdminColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No product imagery added',
                            style: AdminTypography.bodyBold,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Upload photography (JPG, PNG, WebP up to 5 MB) or specify an external image source.',
                            textAlign: TextAlign.center,
                            style: AdminTypography.caption.copyWith(
                              color: AdminColors.muted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          AdminButton.secondary(
                            size: AdminButtonSize.sm,
                            label: 'Select Images',
                            icon: const Icon(
                              Icons.upload_file_outlined,
                              size: 14,
                            ),
                            onPressed: _uploadingImageIndex == null
                                ? _pickImages
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Primary / Gallery status indicator overlay
                if (hasImages)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: AdminBadge(
                      label: isPrimarySelected ? 'Primary Image' : 'Gallery Item',
                      variant: isPrimarySelected
                          ? AdminBadgeVariant.success
                          : AdminBadgeVariant.neutral,
                      showDot: true,
                    ),
                  ),

                // Action to make current preview primary
                if (hasImages && !isPrimarySelected)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: AdminButton.secondary(
                      size: AdminButtonSize.sm,
                      label: 'Set as Primary',
                      icon: const Icon(Icons.star_outline, size: 14),
                      onPressed: () => setState(() {
                        _primaryImageIndex = safePreviewIndex;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Thumbnail Strip Underneath
          if (hasImages) ...[
            Text('GALLERY THUMBNAILS', style: AdminTypography.tableHeader),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < _images.length; i++)
                  _buildThumbnailItem(i, i == safePreviewIndex),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Upload progress bar when busy
          if (_uploadingImageIndex != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _images.isEmpty
                  ? null
                  : (_uploadingImageIndex! + 1) / _images.length,
              color: AdminColors.charcoal,
              backgroundColor: AdminColors.surfaceSubtle,
            ),
            const SizedBox(height: 4),
            Text(
              'Uploading image ${_uploadingImageIndex! + 1} of ${_images.length}…',
              style: AdminTypography.caption,
            ),
            const SizedBox(height: 12),
          ],

          // 3. Image Actions (Upload & Reorder / Delete)
          const Divider(height: 1, thickness: 1, color: AdminColors.line),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AdminButton.secondary(
                key: const ValueKey('pick-product-images'),
                label: 'Upload Images',
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                onPressed: _uploadingImageIndex == null ? _pickImages : null,
              ),
              if (hasImages)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Move Left',
                      icon: const Icon(Icons.chevron_left),
                      onPressed: safePreviewIndex > 0
                          ? () => _moveImage(safePreviewIndex, safePreviewIndex - 1)
                          : null,
                    ),
                    IconButton(
                      tooltip: 'Move Right',
                      icon: const Icon(Icons.chevron_right),
                      onPressed: safePreviewIndex < _images.length - 1
                          ? () => _moveImage(safePreviewIndex, safePreviewIndex + 1)
                          : null,
                    ),
                    IconButton(
                      tooltip: 'Remove selected image',
                      icon: const Icon(Icons.delete_outline,
                          color: AdminColors.error),
                      onPressed: _uploadingImageIndex == null
                          ? () => _removeImage(safePreviewIndex)
                          : null,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Accepted formats: JPG, PNG, WebP up to 5 MB per image.',
            style: AdminTypography.caption.copyWith(color: AdminColors.muted),
          ),
          if (widget.productId == null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 1, color: AdminColors.line),
            const SizedBox(height: 14),
            _refinedTextField(
              _imageUrl,
              'External Image URL',
              key: 'product-image-url',
              placeholder: 'https://...',
              keyboardType: TextInputType.url,
              helperText:
                  'Direct image URL (optional when uploading to gallery)',
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
          ],
        ],
      ),
    );
  }

  Widget _buildThumbnailItem(int index, bool isSelected) {
    final item = _images[index];
    final isPrimary = index == _primaryImageIndex;

    return GestureDetector(
      key: ValueKey('gallery-thumbnail-$index'),
      onTap: () => setState(() => _selectedPreviewIndex = index),
      child: AnimatedContainer(
        duration: AdminMotion.duration(context, AdminMotion.hover),
        curve: AdminMotion.curveFast,
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: AdminColors.surfaceSubtle,
          borderRadius: AdminRadii.radiusXs,
          border: Border.all(
            color: isSelected ? AdminColors.charcoal : AdminColors.line,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: item.savedImage != null
                  ? ProductImage(
                      url: item.savedImage!.url,
                      fit: BoxFit.contain,
                    )
                  : Image.memory(item.bytes!, fit: BoxFit.contain),
            ),
            if (isPrimary)
              Positioned(
                top: 3,
                left: 3,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AdminColors.charcoal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star,
                    size: 9,
                    color: AdminColors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Right Column — Structured Product Information
  // ---------------------------------------------------------------------------
  Widget _buildInformationColumn(
    BuildContext context,
    String? selectedCategory,
    List<ProductCategory> categoryList,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section 1: Basic Information
        AdminCard(
          title: 'Basic Information',
          subtitle: 'Product identification, title and category',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _refinedTextField(
                _name,
                'Product Name',
                key: 'product-name',
                placeholder: 'e.g. Oxford Cotton Shirt',
              ),
              const SizedBox(height: 16),
              _refinedTextField(
                _sku,
                'Product SKU',
                key: 'product-sku',
                placeholder: 'e.g. NOR-OFC-01',
              ),
              const SizedBox(height: 16),
              _refinedTextField(
                _description,
                'Description',
                key: 'product-description',
                maxLines: 4,
                placeholder:
                    'Detailed product narrative, craftsmanship and styling notes...',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('product-category-$selectedCategory'),
                initialValue: selectedCategory,
                style: AdminTypography.body,
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle:
                      AdminTypography.caption.copyWith(color: AdminColors.muted),
                  border: const OutlineInputBorder(
                    borderSide: AdminBorders.sideSubtle,
                    borderRadius: AdminRadii.radiusSm,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: AdminBorders.sideSubtle,
                    borderRadius: AdminRadii.radiusSm,
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: AdminBorders.sideActive,
                    borderRadius: AdminRadii.radiusSm,
                  ),
                  filled: true,
                  fillColor: AdminColors.surfaceSubtle,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                dropdownColor: AdminColors.white,
                borderRadius: AdminRadii.radiusSm,
                items: categoryList
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.name,
                        child: Text(item.name, style: AdminTypography.body),
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
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section 2: Pricing & Valuation
        AdminCard(
          title: 'Pricing & Valuation',
          subtitle: 'Commercial selling price and regular retail reference',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _refinedTextField(
                      _price,
                      'Selling Price (INR)',
                      key: 'product-price',
                      prefixText: '₹ ',
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
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _refinedTextField(
                      _salePrice,
                      'Regular Price (optional)',
                      key: 'product-sale-price',
                      prefixText: '₹ ',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        final regular = int.tryParse(value);
                        final sale = int.tryParse(_price.text);
                        if (regular == null || sale == null || regular <= sale) {
                          return 'Must be greater than selling price.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section 3: External Image Source
        AdminCard(
          title: 'External Image Source',
          subtitle: 'Fallback image URL (optional when uploading to gallery)',
          child: _refinedTextField(
            _imageUrl,
            'External Image URL',
            key: 'product-image-url',
            placeholder: 'https://...',
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
        ),
        const SizedBox(height: 20),

        // Section 4: Variants & Options
        AdminCard(
          title: 'Variants & Sizing Options',
          subtitle: 'Configure size availability and boutique colourways',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                key: const ValueKey('product-requires-size'),
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AdminColors.charcoal,
                title: const Text(
                  'Customer selects a size',
                  style: AdminTypography.bodyMedium,
                ),
                subtitle: const Text(
                  'Enable garment sizing options (e.g. S, M, L, XL)',
                  style: AdminTypography.caption,
                ),
                value: _requiresSize,
                onChanged: (value) => setState(() => _requiresSize = value),
              ),
              if (_requiresSize) ...[
                const SizedBox(height: 10),
                _refinedTextField(
                  _sizes,
                  'Available Sizes',
                  key: 'product-sizes',
                  helperText: 'Separate values with commas (e.g. S, M, L, XL)',
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1, color: AdminColors.line),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                key: const ValueKey('product-requires-color'),
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AdminColors.charcoal,
                title: const Text(
                  'Customer selects a colour',
                  style: AdminTypography.bodyMedium,
                ),
                subtitle: const Text(
                  'Enable fabric or leather colourway choices',
                  style: AdminTypography.caption,
                ),
                value: _requiresColor,
                onChanged: (value) => setState(() => _requiresColor = value),
              ),
              if (_requiresColor) ...[
                const SizedBox(height: 10),
                _refinedTextField(
                  _colors,
                  'Available Colours',
                  key: 'product-colors',
                  helperText:
                      'Separate colour names with commas (e.g. Chalk, Charcoal, Olive)',
                ),
              ],
              if (_existingProduct?.variants.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 1, color: AdminColors.line),
                const SizedBox(height: 14),
                Text(
                  'VARIANT SKU & PRICE OVERRIDES',
                  style: AdminTypography.tableHeader,
                ),
                const SizedBox(height: 4),
                Text(
                  'Customize SKU codes or set individual variant price points',
                  style: AdminTypography.caption,
                ),
                const SizedBox(height: 14),
                for (final variant in _existingProduct!.variants)
                  _refinedVariantEditor(context, variant),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section 5: Inventory & Availability
        AdminCard(
          title: 'Inventory & Stock Level',
          subtitle: 'Catalogue distribution across active variants',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: AdminColors.surfaceSubtle,
                  borderRadius: AdminRadii.radiusSm,
                  border: Border.fromBorderSide(AdminBorders.sideSubtle),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AdminColors.white,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(AdminBorders.sideSubtle),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 20,
                        color: AdminColors.charcoal,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_existingProduct?.stockQuantity ?? 0} Total Units in Stock',
                            style: AdminTypography.bodyBold,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Distributed across ${_existingProduct?.variants.length ?? 0} active variants. Stock adjustments are managed in Admin → Inventory.',
                            style: AdminTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AdminButton.secondary(
                      size: AdminButtonSize.sm,
                      label: 'Manage Stock',
                      icon: const Icon(Icons.stacked_bar_chart_outlined, size: 14),
                      onPressed: () => context.go('/admin/inventory'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section 6: Catalogue Visibility
        AdminCard(
          title: 'Storefront Visibility',
          subtitle: 'Control whether this item is active in the customer shop',
          child: SwitchListTile.adaptive(
            key: const ValueKey('product-active'),
            contentPadding: EdgeInsets.zero,
            activeTrackColor: AdminColors.success,
            title: const Text(
              'Active in customer catalogue',
              style: AdminTypography.bodyMedium,
            ),
            subtitle: const Text(
              'When active, customers can discover and purchase this item in the boutique storefront.',
              style: AdminTypography.caption,
            ),
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
          ),
        ),
        const SizedBox(height: 24),

        // Section 7: Bottom Save & Cancel Action Bar
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AdminButton.secondary(
              label: 'Cancel',
              onPressed: () => context.go('/admin/products'),
            ),
            AdminButton.primary(
              key: const ValueKey('save-product-footer'),
              label: 'Save Changes',
              icon: const Icon(Icons.check, size: 16),
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ],
    );
  }

  Widget _refinedTextField(
    TextEditingController controller,
    String label, {
    required String key,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? helperText,
    String? prefixText,
    String? placeholder,
    String? Function(String?)? validator,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: TextFormField(
          key: ValueKey(key),
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: AdminTypography.body,
          cursorColor: AdminColors.charcoal,
          validator: validator ??
              (value) => (value == null || value.trim().isEmpty)
                  ? 'This field is required.'
                  : null,
          decoration: InputDecoration(
            labelText: label,
            labelStyle:
                AdminTypography.caption.copyWith(color: AdminColors.muted),
            hintText: placeholder,
            hintStyle:
                AdminTypography.caption.copyWith(color: AdminColors.neutralGrey),
            helperText: helperText,
            helperStyle:
                AdminTypography.caption.copyWith(color: AdminColors.neutralGrey),
            prefixText: prefixText,
            prefixStyle: AdminTypography.bodyBold,
            filled: true,
            fillColor: AdminColors.surfaceSubtle,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: const OutlineInputBorder(
              borderSide: AdminBorders.sideSubtle,
              borderRadius: AdminRadii.radiusSm,
            ),
            enabledBorder: const OutlineInputBorder(
              borderSide: AdminBorders.sideSubtle,
              borderRadius: AdminRadii.radiusSm,
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: AdminBorders.sideActive,
              borderRadius: AdminRadii.radiusSm,
            ),
            errorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AdminColors.error),
              borderRadius: AdminRadii.radiusSm,
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AdminColors.error, width: 1.5),
              borderRadius: AdminRadii.radiusSm,
            ),
            alignLabelWithHint: maxLines > 1,
          ),
        ),
      );

  Widget _refinedVariantEditor(BuildContext context, ProductVariant variant) {
    final key = variant.id ?? '${variant.size}|${variant.colorName}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AdminColors.surfaceSubtle,
        borderRadius: AdminRadii.radiusSm,
        border: Border.fromBorderSide(AdminBorders.sideSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Color(variant.colorValue | 0xFF000000),
                  shape: BoxShape.circle,
                  border: Border.all(color: AdminColors.line),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${variant.size} · ${variant.colorName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminTypography.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AdminColors.charcoal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${variant.stockQuantity} in stock',
                style: AdminTypography.caption,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('variant-sku-$key'),
                  initialValue: _variantSkus[key] ?? variant.sku,
                  style: AdminTypography.body,
                  decoration: const InputDecoration(
                    labelText: 'Variant SKU',
                    isDense: true,
                    filled: true,
                    fillColor: AdminColors.white,
                    border: OutlineInputBorder(
                      borderSide: AdminBorders.sideSubtle,
                      borderRadius: AdminRadii.radiusSm,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: AdminBorders.sideSubtle,
                      borderRadius: AdminRadii.radiusSm,
                    ),
                  ),
                  onChanged: (value) => _variantSkus[key] = value,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: ValueKey('variant-price-$key'),
                  initialValue: _variantPriceOverrides[key] ??
                      variant.priceOverride?.toString() ??
                      '',
                  style: AdminTypography.body,
                  decoration: const InputDecoration(
                    labelText: 'Price Override (optional)',
                    prefixText: '₹ ',
                    isDense: true,
                    filled: true,
                    fillColor: AdminColors.white,
                    border: OutlineInputBorder(
                      borderSide: AdminBorders.sideSubtle,
                      borderRadius: AdminRadii.radiusSm,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: AdminBorders.sideSubtle,
                      borderRadius: AdminRadii.radiusSm,
                    ),
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

  void _removeImage(int index) {
    if (index < 0 || index >= _images.length) return;
    setState(() {
      _images.removeAt(index);
      if (_images.isEmpty) {
        _primaryImageIndex = 0;
        _selectedPreviewIndex = 0;
      } else {
        if (_primaryImageIndex >= _images.length) {
          _primaryImageIndex = _images.length - 1;
        } else if (index < _primaryImageIndex) {
          _primaryImageIndex--;
        }
        if (_selectedPreviewIndex >= _images.length) {
          _selectedPreviewIndex = _images.length - 1;
        } else if (index < _selectedPreviewIndex) {
          _selectedPreviewIndex--;
        }
      }
    });
  }

  void _moveImage(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _images.length || oldIndex == newIndex) {
      return;
    }
    setState(() {
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
      _selectedPreviewIndex = newIndex;
    });
  }

  // ===========================================================================
  // REDESIGNED ADD PRODUCT LAYOUT (Wolfpixel Two-Column Architecture)
  // ===========================================================================
  Widget _buildCreateLayout(
    BuildContext context,
    String? selectedCategory,
    List<ProductCategory> categoryList,
  ) {
    return Scaffold(
      backgroundColor: AdminColors.ivory,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            key: const ValueKey('product-form-scroll'),
            slivers: [
              const SliverToBoxAdapter(child: CatalogStateNotice()),
              SliverToBoxAdapter(
                child: AdminPageHeader(
                  breadcrumbs: InkWell(
                    onTap: () => context.go('/admin/products'),
                    borderRadius: AdminRadii.radiusXs,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.arrow_back,
                            size: 14,
                            color: AdminColors.muted,
                          ),
                          SizedBox(width: 6),
                          Text('Products', style: AdminTypography.caption),
                        ],
                      ),
                    ),
                  ),
                  title: 'Add New Product',
                  subtitle:
                      'Introduce a new piece into the boutique catalogue.',
                  actions: [
                    AdminButton.secondary(
                      label: 'Cancel',
                      onPressed: () => context.go('/admin/products'),
                    ),
                    AdminButton.primary(
                      key: const ValueKey('save-product'),
                      label: 'Create Product',
                      icon: const Icon(Icons.add, size: 16),
                      isLoading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 960;
                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column (Gallery) ~40%
                            Expanded(
                              flex: 4,
                              child: _buildGalleryColumn(context),
                            ),
                            const SizedBox(width: 24),
                            // Right Column (Structured Information Cards) ~60%
                            Expanded(
                              flex: 6,
                              child: _buildCreateInformationColumn(
                                context,
                                selectedCategory,
                                categoryList,
                              ),
                            ),
                          ],
                        );
                      }

                      // Stacked Single Column on Tablet / Mobile
                      return Column(
                        children: [
                          _buildGalleryColumn(context),
                          const SizedBox(height: 24),
                          _buildCreateInformationColumn(
                            context,
                            selectedCategory,
                            categoryList,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Right Column — Add Product Structured Information
  // ---------------------------------------------------------------------------
  Widget _buildCreateInformationColumn(
    BuildContext context,
    String? selectedCategory,
    List<ProductCategory> categoryList,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section 1: Basic Information
        AdminCard(
          title: 'Basic Information',
          subtitle: 'Product identification, title and category',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _refinedTextField(
                _name,
                'Product Name',
                key: 'product-name',
                placeholder: 'e.g. Oxford Cotton Shirt',
              ),
              const SizedBox(height: 16),
              _refinedTextField(
                _sku,
                'Product SKU',
                key: 'product-sku',
                placeholder: 'e.g. NOR-OFC-01',
              ),
              const SizedBox(height: 16),
              _refinedTextField(
                _description,
                'Description',
                key: 'product-description',
                maxLines: 4,
                placeholder:
                    'Detailed product narrative, craftsmanship and styling notes...',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('product-category-$selectedCategory'),
                initialValue: selectedCategory,
                style: AdminTypography.body,
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle:
                      AdminTypography.caption.copyWith(color: AdminColors.muted),
                  border: const OutlineInputBorder(
                    borderSide: AdminBorders.sideSubtle,
                    borderRadius: AdminRadii.radiusSm,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: AdminBorders.sideSubtle,
                    borderRadius: AdminRadii.radiusSm,
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: AdminBorders.sideActive,
                    borderRadius: AdminRadii.radiusSm,
                  ),
                  filled: true,
                  fillColor: AdminColors.surfaceSubtle,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                dropdownColor: AdminColors.white,
                borderRadius: AdminRadii.radiusSm,
                items: categoryList
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.name,
                        child: Text(item.name, style: AdminTypography.body),
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
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section 2: Pricing & Valuation
        AdminCard(
          title: 'Pricing & Valuation',
          subtitle: 'Commercial selling price and regular retail reference',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _refinedTextField(
                      _price,
                      'Selling Price (INR)',
                      key: 'product-price',
                      prefixText: '₹ ',
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
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _refinedTextField(
                      _salePrice,
                      'Regular Price (optional)',
                      key: 'product-sale-price',
                      prefixText: '₹ ',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        final regular = int.tryParse(value);
                        final sale = int.tryParse(_price.text);
                        if (regular == null || sale == null || regular <= sale) {
                          return 'Must be greater than selling price.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              Builder(
                builder: (context) {
                  final regular = int.tryParse(_salePrice.text);
                  final sale = int.tryParse(_price.text);
                  if (regular != null && sale != null && regular > sale) {
                    final discount =
                        (((regular - sale) / regular) * 100).round();
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: const BoxDecoration(
                          color: AdminColors.surfaceSubtle,
                          borderRadius: AdminRadii.radiusSm,
                          border: Border.fromBorderSide(AdminBorders.sideSubtle),
                        ),
                        child: Row(
                          children: [
                            AdminBadge(
                              label: '$discount% OFF',
                              variant: AdminBadgeVariant.success,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Customers save ₹${regular - sale} on this product.',
                              style: AdminTypography.caption.copyWith(
                                color: AdminColors.charcoal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section 3: Variants & Sizing Options
        AdminCard(
          title: 'Variants & Sizing Options',
          subtitle: 'Define size and colourway variations for customers',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                key: const ValueKey('product-requires-size'),
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AdminColors.charcoal,
                title: const Text(
                  'Customer selects a size',
                  style: AdminTypography.bodyMedium,
                ),
                subtitle: const Text(
                  'Enable multiple sizing options (e.g. S, M, L, XL)',
                  style: AdminTypography.caption,
                ),
                value: _requiresSize,
                onChanged: (value) => setState(() => _requiresSize = value),
              ),
              if (_requiresSize) ...[
                const SizedBox(height: 8),
                _refinedTextField(
                  _sizes,
                  'Available Sizes',
                  key: 'product-sizes',
                  helperText:
                      'Separate size values with commas (e.g. S, M, L, XL)',
                ),
                const SizedBox(height: 12),
              ],
              const Divider(height: 1, thickness: 1, color: AdminColors.line),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                key: const ValueKey('product-requires-color'),
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AdminColors.charcoal,
                title: const Text(
                  'Customer selects a colour',
                  style: AdminTypography.bodyMedium,
                ),
                subtitle: const Text(
                  'Enable boutique colour selection for this item',
                  style: AdminTypography.caption,
                ),
                value: _requiresColor,
                onChanged: (value) => setState(() => _requiresColor = value),
              ),
              if (_requiresColor) ...[
                const SizedBox(height: 8),
                _refinedTextField(
                  _colors,
                  'Available Colours',
                  key: 'product-colors',
                  helperText:
                      'Separate colour names with commas (e.g. Chalk, Charcoal, Olive)',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section 4: Inventory & Stock Level
        AdminCard(
          title: 'Inventory & Stock Level',
          subtitle:
              'Set initial boutique stock to be distributed across variants',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _refinedTextField(
                _stock,
                'Total Stock Across Variants',
                key: 'product-stock',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                helperText:
                    'Total inventory units allocated to this product upon creation',
                validator: (value) {
                  final stock = int.tryParse(value ?? '');
                  return stock == null || stock < 0
                      ? 'Stock must be zero or more.'
                      : null;
                },
              ),
              const SizedBox(height: 14),
              Builder(
                builder: (context) {
                  final sizes = _sizes.text
                      .split(',')
                      .map((v) => v.trim())
                      .where((v) => v.isNotEmpty)
                      .toList();
                  final colors = _colors.text
                      .split(',')
                      .map((v) => v.trim())
                      .where((v) => v.isNotEmpty)
                      .toList();
                  final sizeCount =
                      _requiresSize ? (sizes.isEmpty ? 1 : sizes.length) : 1;
                  final colorCount =
                      _requiresColor ? (colors.isEmpty ? 1 : colors.length) : 1;
                  final totalCombinations = sizeCount * colorCount;
                  final currentStock = int.tryParse(_stock.text) ?? 0;
                  final perVariant = totalCombinations > 0
                      ? currentStock ~/ totalCombinations
                      : 0;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AdminColors.surfaceSubtle,
                      borderRadius: AdminRadii.radiusSm,
                      border: Border.fromBorderSide(AdminBorders.sideSubtle),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: AdminColors.charcoal,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Will initialize $totalCombinations variant combination${totalCombinations == 1 ? '' : 's'} (~$perVariant units each). Individual SKU overrides and price adjustments can be tailored in Edit Product after creation.',
                            style: AdminTypography.caption.copyWith(
                              color: AdminColors.charcoal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section 5: Catalogue Visibility
        AdminCard(
          title: 'Storefront Visibility',
          subtitle: 'Control whether this item is active in the customer shop',
          child: SwitchListTile.adaptive(
            key: const ValueKey('product-active'),
            contentPadding: EdgeInsets.zero,
            activeTrackColor: AdminColors.success,
            title: const Text(
              'Active in customer catalogue',
              style: AdminTypography.bodyMedium,
            ),
            subtitle: const Text(
              'When active, customers can discover and purchase this item in the boutique storefront.',
              style: AdminTypography.caption,
            ),
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
          ),
        ),
        const SizedBox(height: 24),

        // Section 6: Bottom Save & Cancel Action Bar
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AdminButton.secondary(
              label: 'Cancel',
              onPressed: () => context.go('/admin/products'),
            ),
            AdminButton.primary(
              key: const ValueKey('save-product-footer'),
              label: 'Create Product',
              icon: const Icon(Icons.add, size: 16),
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // BACKEND / PERSISTENCE / FILE PICKING
  // ===========================================================================
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
          if (_images.isEmpty) {
            _primaryImageIndex = 0;
            _selectedPreviewIndex = 0;
          }
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
    if (_saving) return;
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
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/admin/products');
        }
      }
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
