import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_providers.dart';
import '../products/product_catalog_provider.dart';
import '../products/product_repository.dart';
import '../products/widgets/catalog_state_notice.dart';
import '../products/widgets/product_image.dart';
import 'widgets/admin_widgets.dart';

/// Luxury editorial Categories Management screen for the NORVÉ Administration Web platform.
///
/// Combines the ShopDash practical category-card grid and 2-column form structure
/// with NORVÉ's premium fashion-commerce editorial visual identity.
class AdminCategoriesScreen extends ConsumerStatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  ConsumerState<AdminCategoriesScreen> createState() =>
      _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends ConsumerState<AdminCategoriesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'name_asc';
  bool _isGridView = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productCategoriesProvider);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final int crossAxisCount = width >= 1200
              ? 4
              : width >= 860
                  ? 3
                  : width >= 560
                      ? 2
                      : 1;

          return CustomScrollView(
            key: const ValueKey('admin-categories-scroll'),
            slivers: [
              const SliverToBoxAdapter(child: CatalogStateNotice()),

              // Editorial Page Header with Primary Action
              SliverToBoxAdapter(
                child: AdminPageHeader(
                  title: 'Categories',
                  subtitle:
                      'Curate and organize your boutique fashion collections.',
                  actions: [
                    AdminButton.primary(
                      key: const ValueKey('admin-add-category'),
                      onPressed: () => _editCategory(context, ref),
                      icon: const Icon(Icons.add, size: 16),
                      label: 'Add category',
                    ),
                  ],
                ),
              ),

              // Main Content
              ...state.when(
                loading: () => [
                  const SliverFillRemaining(
                    child: Center(
                      child: AdminLoading(message: 'Loading categories...'),
                    ),
                  ),
                ],
                error: (error, stack) => [
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: AdminCard(
                          padding: const EdgeInsets.all(AdminSpacing.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 40,
                                color: AdminColors.error,
                              ),
                              const SizedBox(height: AdminSpacing.md),
                              const Text(
                                'Categories could not be loaded',
                                style: AdminTypography.cardTitle,
                              ),
                              const SizedBox(height: AdminSpacing.xs),
                              Text(
                                error.toString(),
                                style: AdminTypography.caption,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AdminSpacing.lg),
                              AdminButton.secondary(
                                label: 'Retry',
                                onPressed: () =>
                                    ref.invalidate(productCategoriesProvider),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                data: (categories) {
                  if (categories.isEmpty) {
                    return [
                      SliverFillRemaining(
                        child: Center(
                          child: AdminEmptyState(
                            title: 'No categories yet',
                            message:
                                'Create your first boutique category to organize catalogue pieces.',
                            icon: Icons.category_outlined,
                            actionLabel: 'Add category',
                            onAction: () => _editCategory(context, ref),
                          ),
                        ),
                      ),
                    ];
                  }

                  // Compute Genuine Metrics
                  final totalCategories = categories.length;
                  final totalProducts = categories.fold<int>(
                    0,
                    (sum, c) => sum + c.productCount,
                  );
                  final populatedCount =
                      categories.where((c) => c.productCount > 0).length;
                  final emptyCount =
                      categories.where((c) => c.productCount == 0).length;

                  // Filter & Sort
                  final filtered = categories.where((c) {
                    if (_searchQuery.isEmpty) return true;
                    return c.name.toLowerCase().contains(_searchQuery) ||
                        c.description.toLowerCase().contains(_searchQuery);
                  }).toList();

                  _applySorting(filtered);

                  return [
                    // KPI Summary Row (ShopDash Inspired)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: _buildKpiRow(
                          width,
                          totalCategories: totalCategories,
                          totalProducts: totalProducts,
                          populatedCount: populatedCount,
                          emptyCount: emptyCount,
                        ),
                      ),
                    ),

                    // Search, Sort & View Controls Bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: _buildControlsBar(),
                      ),
                    ),

                    // Category Card Grid or Table View
                    if (filtered.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 32,
                          ),
                          child: AdminCard(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.search_off,
                                  size: 40,
                                  color: AdminColors.muted,
                                ),
                                const SizedBox(height: AdminSpacing.md),
                                const Text(
                                  'No matching categories found',
                                  style: AdminTypography.cardTitle,
                                ),
                                const SizedBox(height: AdminSpacing.xs),
                                Text(
                                  'No categories match "$_searchQuery". Check spelling or clear search.',
                                  style: AdminTypography.caption,
                                ),
                                const SizedBox(height: AdminSpacing.lg),
                                AdminButton.secondary(
                                  label: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (_isGridView)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                            mainAxisExtent: 310,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _buildCategoryCard(filtered[index]),
                            childCount: filtered.length,
                          ),
                        ),
                      )
                    else
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                          child: _buildCategoryTable(filtered),
                        ),
                      ),
                  ];
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _applySorting(List<ProductCategory> list) {
    switch (_sortBy) {
      case 'name_desc':
        list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case 'products_desc':
        list.sort((a, b) => b.productCount.compareTo(a.productCount));
        break;
      case 'products_asc':
        list.sort((a, b) => a.productCount.compareTo(b.productCount));
        break;
      case 'name_asc':
      default:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // KPI Summary Row (ShopDash Inspired)
  // ---------------------------------------------------------------------------
  Widget _buildKpiRow(
    double maxWidth, {
    required int totalCategories,
    required int totalProducts,
    required int populatedCount,
    required int emptyCount,
  }) {
    final kpis = [
      (
        label: 'Total Categories',
        value: '$totalCategories',
        caption: 'Boutique catalogue collections',
        icon: Icons.category_outlined,
      ),
      (
        label: 'Total Products',
        value: '$totalProducts',
        caption: 'Pieces assigned across collections',
        icon: Icons.shopping_bag_outlined,
      ),
      (
        label: 'Active Collections',
        value: '$populatedCount',
        caption: 'Collections containing products',
        icon: Icons.check_circle_outline,
      ),
      (
        label: 'Empty Collections',
        value: '$emptyCount',
        caption: 'Eligible for safe deletion',
        icon: Icons.folder_outlined,
      ),
    ];

    if (maxWidth < 960) {
      // 2x2 grid on small and medium screens
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildKpiCard(kpis[0])),
              const SizedBox(width: AdminSpacing.md),
              Expanded(child: _buildKpiCard(kpis[1])),
            ],
          ),
          const SizedBox(height: AdminSpacing.md),
          Row(
            children: [
              Expanded(child: _buildKpiCard(kpis[2])),
              const SizedBox(width: AdminSpacing.md),
              Expanded(child: _buildKpiCard(kpis[3])),
            ],
          ),
        ],
      );
    }

    // 4 columns row on wide screens
    return Row(
      children: [
        for (int i = 0; i < kpis.length; i++) ...[
          if (i > 0) const SizedBox(width: AdminSpacing.md),
          Expanded(child: _buildKpiCard(kpis[i])),
        ],
      ],
    );
  }

  Widget _buildKpiCard(({
    String caption,
    IconData icon,
    String label,
    String value,
  }) kpi) {
    return AdminCard(
      padding: const EdgeInsets.all(AdminSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  kpi.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminTypography.tableHeader.copyWith(
                    color: AdminColors.muted,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: AdminSpacing.xs),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AdminColors.surfaceSubtle,
                  borderRadius: AdminRadii.radiusSm,
                  border: AdminBorders.subtle,
                ),
                child: Icon(kpi.icon, size: 16, color: AdminColors.charcoal),
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.sm),
          Text(
            kpi.value,
            style: AdminTypography.pageTitle.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AdminSpacing.xs),
          Text(
            kpi.caption,
            style: AdminTypography.caption.copyWith(color: AdminColors.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search, Sort & View Controls Bar
  // ---------------------------------------------------------------------------
  Widget _buildControlsBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640;

        final searchField = AdminSearchField(
          controller: _searchController,
          hintText: 'Search categories...',
          onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
          onClear: () => setState(() => _searchQuery = ''),
        );

        final sortDropdown = Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.md),
          decoration: const BoxDecoration(
            color: AdminColors.white,
            border: AdminBorders.subtle,
            borderRadius: AdminRadii.radiusSm,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sortBy,
              isDense: true,
              style: AdminTypography.body,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: AdminColors.muted,
              ),
              dropdownColor: AdminColors.white,
              borderRadius: AdminRadii.radiusSm,
              onChanged: (val) {
                if (val != null) setState(() => _sortBy = val);
              },
              items: const [
                DropdownMenuItem(
                  value: 'name_asc',
                  child: Text('Sort by Name (A-Z)'),
                ),
                DropdownMenuItem(
                  value: 'name_desc',
                  child: Text('Sort by Name (Z-A)'),
                ),
                DropdownMenuItem(
                  value: 'products_desc',
                  child: Text('Most Products'),
                ),
                DropdownMenuItem(
                  value: 'products_asc',
                  child: Text('Fewest Products'),
                ),
              ],
            ),
          ),
        );

        final viewToggle = Container(
          height: 40,
          decoration: const BoxDecoration(
            color: AdminColors.white,
            border: AdminBorders.subtle,
            borderRadius: AdminRadii.radiusSm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Grid View',
                iconSize: 18,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                color: _isGridView ? AdminColors.charcoal : AdminColors.muted,
                icon: const Icon(Icons.grid_view_outlined),
                onPressed: () => setState(() => _isGridView = true),
              ),
              Container(width: 1, height: 20, color: AdminColors.line),
              IconButton(
                tooltip: 'Table View',
                iconSize: 18,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                color: !_isGridView ? AdminColors.charcoal : AdminColors.muted,
                icon: const Icon(Icons.view_list_outlined),
                onPressed: () => setState(() => _isGridView = false),
              ),
            ],
          ),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: AdminSpacing.sm),
              Row(
                children: [
                  Expanded(child: sortDropdown),
                  const SizedBox(width: AdminSpacing.sm),
                  viewToggle,
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: AdminSpacing.md),
            sortDropdown,
            const SizedBox(width: AdminSpacing.md),
            viewToggle,
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Category Grid Card (ShopDash Inspired)
  // ---------------------------------------------------------------------------
  Widget _buildCategoryCard(ProductCategory category) {
    final hasImage =
        category.imageUrl != null && category.imageUrl!.trim().isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: AdminColors.white,
        border: AdminBorders.subtle,
        borderRadius: AdminRadii.radiusSm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Category Banner / Imagery (16:9 Aspect Ratio)
          SizedBox(
            height: 140,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasImage)
                  ProductImage(
                    url: category.imageUrl!.trim(),
                    fit: BoxFit.cover,
                  )
                else
                  Container(
                    color: AdminColors.surfaceSubtle,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.category_outlined,
                            size: 32,
                            color: AdminColors.neutralGrey,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category.name.isNotEmpty
                                ? category.name[0].toUpperCase()
                                : 'C',
                            style: AdminTypography.sectionTitle.copyWith(
                              color: AdminColors.muted,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Top-right Action Buttons
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AdminColors.white.withAlpha(235),
                      borderRadius: AdminRadii.radiusSm,
                      border: AdminBorders.subtle,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit ${category.name}',
                          iconSize: 16,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          color: AdminColors.charcoal,
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              _editCategory(context, ref, category),
                        ),
                        Container(
                          width: 1,
                          height: 16,
                          color: AdminColors.line,
                        ),
                        IconButton(
                          tooltip: 'Delete ${category.name}',
                          iconSize: 16,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          color: category.productCount == 0
                              ? AdminColors.charcoal
                              : AdminColors.neutralGrey,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: category.productCount == 0
                              ? () => _deleteCategory(context, ref, category)
                              : () => _showCannotDelete(
                                  context,
                                  category.productCount,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Card Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AdminSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: AdminTypography.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      category.description.isNotEmpty
                          ? category.description
                          : 'No editorial description provided.',
                      style: AdminTypography.caption.copyWith(
                        color: category.description.isNotEmpty
                            ? AdminColors.muted
                            : AdminColors.neutralGrey,
                        fontStyle: category.description.isNotEmpty
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const AdminDivider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: AdminBadge(
                          label:
                              '${category.productCount} ${category.productCount == 1 ? 'Product' : 'Products'}',
                          variant: category.productCount > 0
                              ? AdminBadgeVariant.neutral
                              : AdminBadgeVariant.draft,
                        ),
                      ),
                      const SizedBox(width: AdminSpacing.xs),
                      Text(
                        category.productCount == 0
                            ? 'Deletable'
                            : 'In Storefront',
                        style: AdminTypography.caption.copyWith(
                          color: category.productCount == 0
                              ? AdminColors.muted
                              : AdminColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Table View Alternative
  // ---------------------------------------------------------------------------
  Widget _buildCategoryTable(List<ProductCategory> categories) {
    return AdminTable(
      children: [
        AdminTableHeader(
          children: const [
            AdminTableHeaderCell(label: 'Category', flex: 3),
            AdminTableHeaderCell(label: 'Description', flex: 4),
            AdminTableHeaderCell(label: 'Products', width: 130),
            AdminTableHeaderCell(label: 'Status', width: 130),
            AdminTableHeaderCell(label: 'Actions', width: 100),
          ],
        ),
        for (final category in categories)
          AdminTableRow(
            children: [
              // 1. Category name + thumbnail
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AdminColors.surfaceSubtle,
                        border: AdminBorders.subtle,
                        borderRadius: AdminRadii.radiusSm,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: category.imageUrl != null &&
                              category.imageUrl!.trim().isNotEmpty
                          ? ProductImage(
                              url: category.imageUrl!.trim(),
                              fit: BoxFit.cover,
                            )
                          : const Center(
                              child: Icon(
                                Icons.category_outlined,
                                size: 16,
                                color: AdminColors.neutralGrey,
                              ),
                            ),
                    ),
                    const SizedBox(width: AdminSpacing.md),
                    Expanded(
                      child: Text(
                        category.name,
                        style: AdminTypography.bodyBold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Description
              Expanded(
                flex: 4,
                child: Text(
                  category.description.isNotEmpty
                      ? category.description
                      : '—',
                  style: AdminTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 3. Products count
              SizedBox(
                width: 130,
                child: Text(
                  '${category.productCount} ${category.productCount == 1 ? 'product' : 'products'}',
                  style: AdminTypography.body,
                ),
              ),

              // 4. Status badge
              SizedBox(
                width: 130,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AdminBadge(
                    label: category.productCount > 0
                        ? 'Populated'
                        : 'Empty Collection',
                    variant: category.productCount > 0
                        ? AdminBadgeVariant.neutral
                        : AdminBadgeVariant.draft,
                  ),
                ),
              ),

              // 5. Actions
              SizedBox(
                width: 100,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Edit ${category.name}',
                      iconSize: 16,
                      color: AdminColors.charcoal,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () =>
                          _editCategory(context, ref, category),
                    ),
                    IconButton(
                      tooltip: 'Delete ${category.name}',
                      iconSize: 16,
                      color: category.productCount == 0
                          ? AdminColors.charcoal
                          : AdminColors.neutralGrey,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: category.productCount == 0
                          ? () => _deleteCategory(context, ref, category)
                          : () => _showCannotDelete(
                              context,
                              category.productCount,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Add / Edit Category Dialog Form (ShopDash-Inspired 2-Column Structure)
  // ---------------------------------------------------------------------------
  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref, [
    ProductCategory? category,
  ]) async {
    final data =
        await showDialog<({String name, String description, String imageUrl})>(
      context: context,
      barrierColor: AdminColors.charcoal.withAlpha(120),
      builder: (dialogContext) => _CategoryFormDialog(category: category),
    );

    if (data == null || !context.mounted) return;

    try {
      await ref.read(productRepositoryProvider).saveCategory(
            ProductCategory(
              id: category?.id ?? '',
              name: data.name,
              slug: '',
              description: data.description,
              imageUrl: data.imageUrl,
            ),
            create: category == null,
          );
      ref.invalidate(productCategoriesProvider);
      ref.invalidate(productCatalogProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category saved.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category could not be saved: $error')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Delete Category & Safeguards
  // ---------------------------------------------------------------------------
  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    ProductCategory category,
  ) async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: const Color(0x66000000),
      transitionDuration: AdminMotion.duration(context, AdminMotion.modal),
      pageBuilder: (context, anim, secAnim) => AlertDialog(
        backgroundColor: AdminColors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: AdminRadii.radiusSm,
          side: AdminBorders.sideSubtle,
        ),
        title: const Text('Delete category?', style: AdminTypography.modalTitle),
        content: Text(
          'The category will be removed. Categories with products cannot be deleted; reassign those products first.',
          style: AdminTypography.body.copyWith(color: AdminColors.muted),
        ),
        actions: [
          AdminButton.secondary(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context, false),
          ),
          const SizedBox(width: AdminSpacing.xs),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminColors.error,
              foregroundColor: AdminColors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: AdminRadii.radiusSm,
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete category'),
          ),
        ],
      ),
      transitionBuilder: (context, anim, secAnim, child) {
        final curve = CurvedAnimation(
          parent: anim,
          curve: AdminMotion.curveDecelerate,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(productRepositoryProvider).deleteCategory(category.id);
      ref.invalidate(productCategoriesProvider);
      ref.invalidate(productCatalogProvider);
      if (context.mounted) {
        AdminSnackbar.show(context, message: 'Category deleted.');
      }
    } catch (error) {
      if (context.mounted) {
        AdminSnackbar.show(
          context,
          message: 'Category could not be deleted: $error',
          isError: true,
        );
      }
    }
  }

  void _showCannotDelete(BuildContext context, int count) {
    AdminConfirmationDialog.show(
      context,
      title: 'Category contains products',
      message:
          'Reassign or delete the $count products in this category before deleting it.',
      confirmLabel: 'Close',
      cancelLabel: null,
    );
  }
}

/// Dedicated stateful dialog for creating and editing categories with 2-column layout.
class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({this.category});

  final ProductCategory? category;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _imageUrl;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? '');
    _description =
        TextEditingController(text: widget.category?.description ?? '');
    _imageUrl = TextEditingController(text: widget.category?.imageUrl ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.category == null;

    return Dialog(
      backgroundColor: AdminColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: const RoundedRectangleBorder(
        borderRadius: AdminRadii.radiusMd,
        side: AdminBorders.sideSubtle,
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 660),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: const BoxDecoration(
                color: AdminColors.surfaceSubtle,
                border: Border(bottom: AdminBorders.sideSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isNew ? 'Add category' : 'Edit category',
                          style: AdminTypography.sectionTitle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isNew
                              ? 'Create a new collection category for your boutique catalogue.'
                              : 'Update category information, editorial description, and banner imagery.',
                          style: AdminTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AdminColors.muted,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Modal Body with 2-Column Responsive Layout
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 640;

                      final generalInfoSection = AdminCard(
                        title: 'General Information',
                        subtitle:
                            'Customer-facing category name and editorial notes.',
                        padding: const EdgeInsets.all(AdminSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Category Name',
                              style: AdminTypography.label,
                            ),
                            const SizedBox(height: AdminSpacing.xs),
                            TextFormField(
                              controller: _name,
                              cursorColor: AdminColors.charcoal,
                              style: AdminTypography.body,
                              decoration: InputDecoration(
                                labelText: isNew ? 'Category name' : null,
                                hintText:
                                    'e.g. Knitwear, Outerwear, Tailoring',
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
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'Enter a category name.'
                                      : null,
                            ),
                            const SizedBox(height: AdminSpacing.lg),
                            Text(
                              'Description',
                              style: AdminTypography.label,
                            ),
                            const SizedBox(height: AdminSpacing.xs),
                            TextFormField(
                              controller: _description,
                              cursorColor: AdminColors.charcoal,
                              style: AdminTypography.body,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: isNew ? 'Description' : null,
                                hintText:
                                    'Enter an editorial description of this seasonal collection...',
                                alignLabelWithHint: true,
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
                              ),
                            ),
                          ],
                        ),
                      );

                      final mediaSection = AdminCard(
                        title: 'Category Media',
                        subtitle:
                            'Visual banner for storefront navigation.',
                        padding: const EdgeInsets.all(AdminSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isNew ? 'Image URL' : 'Image URL (Optional)',
                              style: AdminTypography.label,
                            ),
                            const SizedBox(height: AdminSpacing.xs),
                            TextFormField(
                              controller: _imageUrl,
                              cursorColor: AdminColors.charcoal,
                              style: AdminTypography.body,
                              keyboardType: TextInputType.url,
                              decoration: InputDecoration(
                                labelText: isNew ? 'Image URL (optional)' : null,
                                hintText:
                                    'https://example.com/collection.jpg',
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
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return null;
                                }
                                final uri = Uri.tryParse(value.trim());
                                return uri != null &&
                                        {'http', 'https'}
                                            .contains(uri.scheme) &&
                                        uri.host.isNotEmpty
                                    ? null
                                    : 'Enter a valid image URL.';
                              },
                            ),
                            const SizedBox(height: AdminSpacing.md),
                            Text(
                              'Live Preview',
                              style: AdminTypography.caption.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AdminSpacing.xs),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _imageUrl,
                              builder: (context, value, _) {
                                final trimmed = value.text.trim();
                                final uri = Uri.tryParse(trimmed);
                                final isValid = uri != null &&
                                    {'http', 'https'}.contains(uri.scheme) &&
                                    uri.host.isNotEmpty;

                                if (isValid) {
                                  return Container(
                                    height: 120,
                                    width: double.infinity,
                                    decoration: const BoxDecoration(
                                      color: AdminColors.surfaceSubtle,
                                      border: AdminBorders.subtle,
                                      borderRadius: AdminRadii.radiusSm,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: ProductImage(
                                      url: trimmed,
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                }

                                return Container(
                                  height: 120,
                                  width: double.infinity,
                                  decoration: const BoxDecoration(
                                    color: AdminColors.surfaceSubtle,
                                    border: AdminBorders.subtle,
                                    borderRadius: AdminRadii.radiusSm,
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.cloud_upload_outlined,
                                          size: 24,
                                          color: AdminColors.muted,
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'No image preview available',
                                          style: AdminTypography.caption,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );

                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 58, child: generalInfoSection),
                            const SizedBox(width: AdminSpacing.xl),
                            Expanded(flex: 42, child: mediaSection),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          generalInfoSection,
                          const SizedBox(height: AdminSpacing.xl),
                          mediaSection,
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            // Modal Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              decoration: const BoxDecoration(
                color: AdminColors.surfaceSubtle,
                border: Border(top: AdminBorders.sideSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AdminColors.charcoal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AdminSpacing.md),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminColors.charcoal,
                      foregroundColor: AdminColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AdminRadii.radiusSm,
                      ),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        Navigator.pop(
                          context,
                          (
                            name: _name.text.trim(),
                            description: _description.text.trim(),
                            imageUrl: _imageUrl.text.trim(),
                          ),
                        );
                      }
                    },
                    child: const Text('Save category'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
