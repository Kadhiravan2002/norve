import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../core/theme/norve_theme.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.url, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final pixelRatio = MediaQuery.devicePixelRatioOf(context);
      final cacheWidth = _decodeDimension(constraints.maxWidth, pixelRatio);
      final cacheHeight = _decodeDimension(constraints.maxHeight, pixelRatio);

      // Keep the existing HTML-element fallback for external images on Web.
      // cached_network_image's persistent file cache is used on native
      // platforms; browsers continue to use their normal HTTP image cache.
      if (kIsWeb) {
        return Image.network(
          url,
          fit: fit,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          errorBuilder: (context, error, stackTrace) => const _ImageFallback(),
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : const _ImageFallback(showLoader: true),
        );
      }

      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        memCacheWidth: cacheWidth,
        memCacheHeight: cacheHeight,
        placeholder: (context, imageUrl) =>
            const _ImageFallback(showLoader: true),
        errorWidget: (context, imageUrl, error) => const _ImageFallback(),
      );
    },
  );

  int? _decodeDimension(double logicalPixels, double pixelRatio) {
    if (!logicalPixels.isFinite || logicalPixels <= 0) return null;
    return (logicalPixels * pixelRatio).ceil().clamp(1, 1600);
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({this.showLoader = false});

  final bool showLoader;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFEAE5DC),
    child: Center(
      child: showLoader
          ? const Icon(Icons.image_outlined, size: 20, color: NorveColors.muted)
          : const Icon(
              Icons.image_outlined,
              size: 28,
              color: NorveColors.muted,
            ),
    ),
  );
}
