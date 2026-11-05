import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/products/widgets/product_image.dart';

/// Product images: swipe and dots on phones; thumbnails, arrows, mouse drag
/// and arrow keys on larger screens.
class ProductGallery extends StatefulWidget {
  const ProductGallery({
    super.key,
    required this.images,
    required this.height,
    required this.compact,
  });

  final List<String> images;
  final double height;

  /// Phone layout: edge-to-edge images with dots.
  final bool compact;

  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  final _controller = PageController();
  final _focusNode = FocusNode(debugLabel: 'product-gallery');
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _show(int index) {
    if (index < 0 || index >= widget.images.length) return;
    setState(() => _index = index);
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(index);
    } else {
      _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _show(_index + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _show(_index - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final many = widget.images.length > 1;
    final main = SizedBox(
      height: widget.height,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: many,
        onKeyEvent: _onKey,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (_) => _focusNode.requestFocus(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ScrollConfiguration(
                behavior: const _GalleryScrollBehavior(),
                child: PageView.builder(
                  key: const ValueKey('product-gallery'),
                  controller: _controller,
                  itemCount: widget.images.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) => ProductImage(
                    url: widget.images[index],
                    fit: widget.compact ? BoxFit.cover : BoxFit.contain,
                  ),
                ),
              ),
              if (many && widget.compact) _dots(),
              if (many && !widget.compact) ...[
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _Arrow(
                      arrowKey: 'gallery-previous',
                      icon: Icons.chevron_left,
                      label: 'Previous image',
                      onPressed: _index == 0 ? null : () => _show(_index - 1),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _Arrow(
                      arrowKey: 'gallery-next',
                      icon: Icons.chevron_right,
                      label: 'Next image',
                      onPressed: _index == widget.images.length - 1
                          ? null
                          : () => _show(_index + 1),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!many || widget.compact) return main;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        main,
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < widget.images.length; index++)
              Semantics(
                button: true,
                selected: index == _index,
                label: 'View image ${index + 1}',
                excludeSemantics: true,
                child: InkWell(
                  key: ValueKey('gallery-thumbnail-$index'),
                  onTap: () => _show(index),
                  child: Container(
                    width: 64,
                    height: 84,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: index == _index
                            ? NorveColors.charcoal
                            : NorveColors.line,
                      ),
                    ),
                    child: ProductImage(url: widget.images[index]),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _dots() => Positioned(
    bottom: 14,
    left: 0,
    right: 0,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < widget.images.length; index++)
          Container(
            width: index == _index ? 18 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: index == _index
                  ? NorveColors.white
                  : NorveColors.white.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    ),
  );
}

class _GalleryScrollBehavior extends MaterialScrollBehavior {
  const _GalleryScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.arrowKey,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String arrowKey;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: NorveColors.white.withValues(alpha: 0.92),
    shape: const CircleBorder(),
    child: IconButton(
      key: ValueKey(arrowKey),
      tooltip: label,
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
    ),
  );
}
