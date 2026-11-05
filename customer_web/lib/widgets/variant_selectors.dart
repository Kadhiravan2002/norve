import 'package:flutter/material.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/products/product.dart';

/// Size choices, matching the mobile app's styling.
class SizeOption extends StatelessWidget {
  const SizeOption({
    super.key,
    required this.size,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String size;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    selected: selected,
    label: enabled ? 'Size $size' : 'Size $size, unavailable',
    excludeSemantics: true,
    child: InkWell(
      key: ValueKey('size-option-$size'),
      onTap: enabled ? onTap : null,
      child: CustomPaint(
        foregroundPainter: enabled ? null : const _UnavailableLinePainter(),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 140),
          constraints: const BoxConstraints(minWidth: 55),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? NorveColors.charcoal
                : enabled
                ? Colors.transparent
                : NorveColors.line.withValues(alpha: 0.45),
            border: Border.all(
              color: selected ? NorveColors.charcoal : NorveColors.line,
            ),
          ),
          // widthFactor keeps the button sized to its label inside a Wrap.
          child: Center(
            widthFactor: 1,
            child: Text(
              size,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: enabled
                    ? (selected ? NorveColors.white : NorveColors.charcoal)
                    : NorveColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Colour swatches, matching the mobile app's styling.
class ColorOption extends StatelessWidget {
  const ColorOption({
    super.key,
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ProductColor color;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: enabled ? color.name : '${color.name}, unavailable',
    child: Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: enabled ? color.name : '${color.name}, unavailable',
      excludeSemantics: true,
      child: InkResponse(
        key: ValueKey('color-option-${color.name}'),
        onTap: enabled ? onTap : null,
        radius: 24,
        child: Container(
          width: 36,
          height: 36,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? NorveColors.charcoal : Colors.transparent,
            ),
          ),
          child: CustomPaint(
            foregroundPainter: enabled
                ? null
                : const _UnavailableLinePainter(circular: true),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(color.value),
                border: Border.all(color: NorveColors.line),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _UnavailableLinePainter extends CustomPainter {
  const _UnavailableLinePainter({this.circular = false});

  final bool circular;

  @override
  void paint(Canvas canvas, Size size) {
    if (circular) canvas.clipPath(Path()..addOval(Offset.zero & size));
    canvas.drawLine(
      Offset(3, size.height - 3),
      Offset(size.width - 3, 3),
      Paint()
        ..color = NorveColors.muted.withValues(alpha: 0.72)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _UnavailableLinePainter oldDelegate) =>
      circular != oldDelegate.circular;
}

class QuantitySelector extends StatelessWidget {
  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    decoration: BoxDecoration(border: Border.all(color: NorveColors.line)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey('quantity-decrease'),
          tooltip: 'Decrease quantity',
          onPressed: onDecrease,
          icon: const Icon(Icons.remove, size: 17),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$quantity',
            key: const ValueKey('quantity-value'),
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          key: const ValueKey('quantity-increase'),
          tooltip: 'Increase quantity',
          onPressed: onIncrease,
          icon: const Icon(Icons.add, size: 17),
        ),
      ],
    ),
  );
}
