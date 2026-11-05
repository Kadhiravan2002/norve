import 'package:flutter/material.dart';
import 'package:norve/core/theme/norve_theme.dart';

import '../catalog/product_description.dart';

class ProductDescriptionView extends StatelessWidget {
  const ProductDescriptionView({super.key, required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(height: 1.65, color: NorveColors.muted);

    TextSpan rich(List<DescriptionSpan> spans) => TextSpan(
      style: base,
      children: [
        for (final span in spans)
          TextSpan(
            text: span.text,
            style: span.bold
                ? const TextStyle(
                    color: NorveColors.charcoal,
                    fontWeight: FontWeight.w600,
                  )
                : null,
          ),
      ],
    );

    final blocks = parseProductDescription(description);
    return Column(
      key: const ValueKey('product-description'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < blocks.length; index++)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
            child: switch (blocks[index]) {
              DescriptionParagraph(:final spans) => Text.rich(rich(spans)),
              DescriptionBulletList(:final items) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 16, child: Text('•', style: base)),
                          Expanded(child: Text.rich(rich(item))),
                        ],
                      ),
                    ),
                ],
              ),
            },
          ),
      ],
    );
  }
}
