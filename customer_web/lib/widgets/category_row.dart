import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/products/product_repository.dart';

import '../app/breakpoints.dart';

/// All, New Arrivals and each category. Scrolls sideways on phones and wraps
/// on wider screens, where a sideways list is awkward with a mouse.
class CategoryRow extends StatelessWidget {
  const CategoryRow({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.newArrivalsSelected,
  });

  final List<ProductCategory> categories;
  final String? selectedCategoryId;
  final bool newArrivalsSelected;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = StorefrontBreakpoints.gutter(width);
    final chips = [
      _CategoryChip(
        chipKey: 'home-category-all',
        label: 'All',
        selected: selectedCategoryId == null && !newArrivalsSelected,
        onTap: () => context.go('/'),
      ),
      _CategoryChip(
        chipKey: 'home-category-new-arrivals',
        label: 'New Arrivals',
        selected: newArrivalsSelected,
        onTap: () => context.go('/?newArrivals=true'),
      ),
      for (final category in categories)
        _CategoryChip(
          chipKey: 'home-category-${category.id}',
          label: category.name,
          selected: category.id == selectedCategoryId,
          onTap: () => context.go(
            Uri(
              path: '/',
              queryParameters: {'categoryId': category.id},
            ).toString(),
          ),
        ),
      if (categories.isEmpty)
        const _CategoryChip(
          chipKey: 'home-category-empty',
          label: 'No active categories',
          selected: false,
        ),
    ];

    if (StorefrontBreakpoints.isPhone(width)) {
      return SizedBox(
        height: 57,
        child: ScrollConfiguration(
          behavior: const _DragScrollBehavior(),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 4),
            scrollDirection: Axis.horizontal,
            itemCount: chips.length,
            separatorBuilder: (context, index) => const SizedBox(width: 26),
            itemBuilder: (context, index) => Center(child: chips[index]),
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 4),
      child: Wrap(spacing: 32, runSpacing: 8, children: chips),
    );
  }
}

/// Lets a mouse drag this row in a narrow desktop window, as touch can.
class _DragScrollBehavior extends MaterialScrollBehavior {
  const _DragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.chipKey,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String chipKey;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    selected: selected,
    label: onTap == null ? label : 'Show $label products',
    excludeSemantics: true,
    child: InkWell(
      key: ValueKey(chipKey),
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? NorveColors.charcoal : Colors.transparent,
            ),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 13,
            color: selected ? NorveColors.charcoal : NorveColors.muted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    ),
  );
}
