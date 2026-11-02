import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/features/products/widgets/product_image.dart';

void main() {
  testWidgets('remote product image uses platform-appropriate caching', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 120,
          height: 120,
          child: ProductImage(url: 'https://images.example.invalid/item.jpg'),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    if (provider is ResizeImage) {
      expect(provider.imageProvider, isA<CachedNetworkImageProvider>());
    } else {
      expect(provider, isA<NetworkImage>());
      expect(
        (provider as NetworkImage).webHtmlElementStrategy,
        WebHtmlElementStrategy.fallback,
      );
    }
  });
}
