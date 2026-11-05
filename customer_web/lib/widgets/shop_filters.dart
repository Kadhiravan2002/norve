import 'package:flutter/material.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/products/product_repository.dart';

import '../catalog/catalog_query.dart';

const _allCategories = '__all_categories__';

InputDecoration _fieldDecoration(String label) => InputDecoration(
  labelText: label,
  isDense: true,
  filled: true,
  fillColor: NorveColors.white,
);

/// The category, availability and sort dropdowns.
class ShopFilterFields extends StatelessWidget {
  const ShopFilterFields({
    super.key,
    required this.query,
    required this.categories,
    required this.onChanged,
    this.horizontal = false,
  });

  final CatalogQuery query;
  final List<ProductCategory> categories;
  final ValueChanged<CatalogQuery> onChanged;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final selectedCategory =
        categories.any((category) => category.id == query.categoryId)
        ? query.categoryId!
        : _allCategories;

    final fields = <Widget>[
      _Dropdown<String>(
        // Rebuilding on change keeps the field in step with Back and Clear.
        key: ValueKey('shop-category-filter-$selectedCategory'),
        label: 'Category',
        value: selectedCategory,
        items: {
          _allCategories: 'All categories',
          for (final category in categories) category.id: category.name,
        },
        onChanged: (id) => onChanged(
          query.copyWith(categoryId: () => id == _allCategories ? null : id),
        ),
      ),
      _Dropdown<CatalogueAvailability>(
        key: ValueKey('shop-availability-filter-${query.availability.param}'),
        label: 'Availability',
        value: query.availability,
        items: {
          for (final option in CatalogueAvailability.values)
            option: option.label,
        },
        onChanged: (value) => onChanged(query.copyWith(availability: value)),
      ),
      _Dropdown<CatalogueSort>(
        key: ValueKey('shop-sort-filter-${query.sort.param}'),
        label: 'Sort',
        value: query.sort,
        items: {
          for (final option in CatalogueSort.values) option: option.label,
        },
        onChanged: (value) => onChanged(query.copyWith(sort: value)),
      ),
    ];

    if (horizontal) {
      return Row(
        children: [
          for (var index = 0; index < fields.length; index++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == fields.length - 1 ? 0 : 12,
                ),
                child: fields[index],
              ),
            ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final field in fields)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: field),
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: value,
    decoration: _fieldDecoration(label),
    style: Theme.of(context).textTheme.bodyMedium,
    isExpanded: true,
    menuMaxHeight: 360,
    dropdownColor: NorveColors.white,
    borderRadius: BorderRadius.circular(4),
    items: [
      for (final item in items.entries)
        DropdownMenuItem(
          value: item.key,
          child: Text(item.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (next) {
      if (next != null) onChanged(next);
    },
  );
}

/// Opens the phone and tablet filter sheet. Changes apply together, as a
/// single browser history entry, when the customer confirms them.
Future<CatalogQuery?> showShopFilterSheet(
  BuildContext context, {
  required CatalogQuery query,
  required List<ProductCategory> categories,
}) => showModalBottomSheet<CatalogQuery>(
  context: context,
  // Covers the site header too, so a tap outside only closes the sheet.
  useRootNavigator: true,
  isScrollControlled: true,
  backgroundColor: NorveColors.ivory,
  shape: const RoundedRectangleBorder(),
  builder: (context) => _FilterSheet(query: query, categories: categories),
);

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.query, required this.categories});

  final CatalogQuery query;
  final List<ProductCategory> categories;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late CatalogQuery _draft = widget.query;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      key: const ValueKey('shop-filter-sheet'),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Filters',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              TextButton(
                key: const ValueKey('shop-sheet-clear'),
                onPressed: () => setState(
                  () => _draft = CatalogQuery(search: _draft.search),
                ),
                child: const Text('Clear filters'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ShopFilterFields(
            query: _draft,
            categories: widget.categories,
            onChanged: (next) => setState(() => _draft = next),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 48,
            child: FilledButton(
              key: const ValueKey('shop-sheet-apply'),
              onPressed: () => Navigator.of(context).pop(_draft),
              child: const Text('Show results'),
            ),
          ),
        ],
      ),
    ),
  );
}
