import 'package:flutter/material.dart';

import '../product.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final viewportWidth = MediaQuery.sizeOf(context).width;
      final width = viewportWidth < 768
          ? viewportWidth
          : constraints.crossAxisExtent;
      final columns = width < 768
          ? (width >= 650 ? 3 : 2)
          : width >= 1400
          ? 5
          : width >= 1024
          ? 4
          : 3;
      return SliverGrid.builder(
        itemCount: products.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: width >= 768 ? 20 : 12,
          mainAxisSpacing: width >= 768 ? 28 : 22,
          childAspectRatio: width < 360
              ? 0.53
              : width >= 768
              ? 0.64
              : 0.57,
        ),
        itemBuilder: (context, index) => ProductCard(product: products[index]),
      );
    },
  );
}
