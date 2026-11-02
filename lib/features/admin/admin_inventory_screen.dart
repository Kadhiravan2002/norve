import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/norve_theme.dart';
import '../../core/supabase/supabase_providers.dart';
import '../products/product.dart';
import '../products/product_catalog_provider.dart';
import '../products/product_repository.dart';
import '../products/widgets/catalog_state_notice.dart';
import 'admin_metrics.dart';

class AdminInventoryScreen extends ConsumerStatefulWidget {
  const AdminInventoryScreen({super.key});

  @override
  ConsumerState<AdminInventoryScreen> createState() =>
      _AdminInventoryScreenState();
}

class _AdminInventoryScreenState extends ConsumerState<AdminInventoryScreen> {
  String _query = '';
  String _category = 'All categories';

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(productCatalogProvider);
    final status = ref.watch(catalogLoadStateProvider);
    final categories =
        ref.watch(productCategoriesProvider).asData?.value ??
        const <ProductCategory>[];
    final available =
        status.phase == CatalogPhase.live ||
        status.phase == CatalogPhase.development;
    final products = catalog.where((product) {
      final matchesQuery = '${product.name} ${product.sku}'
          .toLowerCase()
          .contains(_query.toLowerCase());
      return matchesQuery &&
          (_category == 'All categories' || product.category == _category);
    }).toList();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: CatalogStateNotice()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inventory',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Stock is updated per variant. Order placement continues to deduct stock atomically.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: NorveColors.muted),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final search = TextField(
                        key: const ValueKey('inventory-search'),
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                          hintText: 'Search product or SKU',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      );
                      final category = DropdownButtonFormField<String>(
                        key: ValueKey('inventory-category-$_category'),
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items:
                            <String>[
                                  'All categories',
                                  ...categories.map((item) => item.name),
                                ]
                                .map(
                                  (name) => DropdownMenuItem(
                                    value: name,
                                    child: Text(name),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) => setState(
                          () => _category = value ?? 'All categories',
                        ),
                      );
                      return constraints.maxWidth < 550
                          ? Column(
                              children: [
                                search,
                                const SizedBox(height: 10),
                                category,
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: search),
                                const SizedBox(width: 12),
                                SizedBox(width: 220, child: category),
                              ],
                            );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (available && catalog.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('No products in the catalogue.')),
            )
          else if (available && products.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('No products match these filters.')),
            )
          else if (available)
            SliverList.separated(
              itemCount: products.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _ProductInventory(product: products[index]),
            ),
        ],
      ),
    );
  }
}

class _ProductInventory extends StatelessWidget {
  const _ProductInventory({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.stockQuantity == 0;
    final lowStock =
        product.stockQuantity > 0 && product.stockQuantity <= lowStockThreshold;
    return ExpansionTile(
      key: ValueKey('inventory-${product.id}'),
      onExpansionChanged: null,
      title: Text(product.name),
      subtitle: Text(
        '${product.sku} · ${product.category} · ${product.isActive ? 'Active' : 'Draft'}',
      ),
      leading: Icon(
        outOfStock || lowStock
            ? Icons.warning_amber_outlined
            : Icons.inventory_2_outlined,
        color: NorveColors.charcoal,
      ),
      trailing: AdminStatusChip(
        label: outOfStock
            ? 'OUT OF STOCK'
            : lowStock
            ? 'LOW · ${product.stockQuantity}'
            : '${product.stockQuantity} units',
      ),
      children: product.variants.isEmpty
          ? [
              const ListTile(
                title: Text('Variant detail unavailable'),
                subtitle: Text(
                  'Refresh the live catalogue after applying the Phase 6 migration.',
                ),
              ),
            ]
          : [
              for (final variant in product.variants)
                _VariantStockRow(product: product, variant: variant),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () =>
                      context.push('/admin/products/${product.id}/edit'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Manage variants'),
                ),
              ),
            ],
    );
  }
}

class _VariantStockRow extends ConsumerStatefulWidget {
  const _VariantStockRow({required this.product, required this.variant});
  final Product product;
  final ProductVariant variant;

  @override
  ConsumerState<_VariantStockRow> createState() => _VariantStockRowState();
}

class _VariantStockRowState extends ConsumerState<_VariantStockRow> {
  late final TextEditingController _stock;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _stock = TextEditingController(text: '${widget.variant.stockQuantity}');
  }

  @override
  void dispose() {
    _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final variant = widget.variant;
    final label = [
      variant.size == 'One Size' ? null : variant.size,
      variant.colorName == 'Standard' ? null : variant.colorName,
    ].whereType<String>().join(' · ');
    final low =
        variant.stockQuantity > 0 && variant.stockQuantity <= lowStockThreshold;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.isEmpty ? 'Single option' : label),
                Text(
                  variant.sku,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: NorveColors.muted),
                ),
              ],
            ),
          ),
          Switch(
            value: variant.isAvailable,
            onChanged: _saving ? null : _setAvailability,
          ),
          if (variant.stockQuantity == 0)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Text('OUT'),
            )
          else if (low)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Text('LOW'),
            ),
          SizedBox(
            width: 88,
            child: TextField(
              controller: _stock,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Stock',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Save stock',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final quantity = int.tryParse(_stock.text);
    if (quantity == null || quantity < 0 || widget.variant.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid non-negative quantity for a saved variant.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(productRepositoryProvider)
          .setVariantStock(widget.variant.id!, quantity);
      await ref.read(productCatalogProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Stock updated.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock could not be updated: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setAvailability(bool value) async {
    final id = widget.variant.id;
    if (id == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(productRepositoryProvider)
          .setVariantStock(id, null, isAvailable: value);
      await ref.read(productCatalogProvider.notifier).refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Availability could not be updated: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
