import 'package:flutter/material.dart';
import 'package:norve/features/products/product.dart';

import '../app/breakpoints.dart';
import 'store_product_card.dart';

/// Same column counts as the mobile grid: 2 or 3 on phones, 3 on tablets,
/// then 4, then 5 on the widest screens.
int storeGridColumns(double width) {
  if (width < StorefrontBreakpoints.tablet) return width >= 650 ? 3 : 2;
  if (width >= 1400) return 5;
  return width >= StorefrontBreakpoints.desktop ? 4 : 3;
}

class StoreProductGrid extends StatelessWidget {
  const StoreProductGrid({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.crossAxisExtent;
      final phone = width < StorefrontBreakpoints.tablet;
      final columns = storeGridColumns(width);
      final spacing = phone ? 12.0 : 20.0;
      final cardWidth = (width - spacing * (columns - 1)) / columns;
      return SliverGrid.builder(
        itemCount: products.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: spacing,
          mainAxisSpacing: phone ? 22 : 32,
          mainAxisExtent:
              cardWidth / storeProductImageAspectRatio + storeProductTextHeight,
        ),
        itemBuilder: (context, index) =>
            StoreProductCard(product: products[index]),
      );
    },
  );
}
