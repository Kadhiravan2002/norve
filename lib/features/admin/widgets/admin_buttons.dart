import 'package:flutter/material.dart';

import '../../../core/theme/norve_admin_tokens.dart';

enum AdminButtonVariant { primary, secondary, destructive, ghost }

enum AdminButtonSize { sm, md, lg }

/// Reusable button component reflecting NORVÉ's premium hybrid design system
/// with polished micro-interactions (hover, pressed, focus, disabled, loading).
class AdminButton extends StatefulWidget {
  const AdminButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AdminButtonVariant.primary,
    this.size = AdminButtonSize.md,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  const AdminButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = AdminButtonSize.md,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : variant = AdminButtonVariant.primary;

  const AdminButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = AdminButtonSize.md,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : variant = AdminButtonVariant.secondary;

  const AdminButton.destructive({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = AdminButtonSize.md,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : variant = AdminButtonVariant.destructive;

  const AdminButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = AdminButtonSize.md,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : variant = AdminButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final AdminButtonVariant variant;
  final AdminButtonSize size;
  final bool isLoading;
  final bool isFullWidth;

  @override
  State<AdminButton> createState() => _AdminButtonState();
}

class _AdminButtonState extends State<AdminButton> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    final double height = switch (widget.size) {
      AdminButtonSize.sm => 34,
      AdminButtonSize.md => 42,
      AdminButtonSize.lg => 48,
    };

    final EdgeInsetsGeometry padding = switch (widget.size) {
      AdminButtonSize.sm => const EdgeInsets.symmetric(horizontal: 12),
      AdminButtonSize.md => const EdgeInsets.symmetric(horizontal: 18),
      AdminButtonSize.lg => const EdgeInsets.symmetric(horizontal: 24),
    };

    final double fontSize = switch (widget.size) {
      AdminButtonSize.sm => 12,
      AdminButtonSize.md => 13,
      AdminButtonSize.lg => 14,
    };

    final Color bgColor = switch (widget.variant) {
      AdminButtonVariant.primary => !isEnabled
          ? AdminColors.charcoal.withAlpha(128)
          : _isPressed
              ? const Color(0xFF191715)
              : _isHovered
                  ? const Color(0xFF332F2B)
                  : AdminColors.charcoal,
      AdminButtonVariant.secondary => !isEnabled
          ? AdminColors.white.withAlpha(160)
          : _isPressed
              ? const Color(0xFFF0EBE1)
              : _isHovered
                  ? AdminColors.surfaceSubtle
                  : AdminColors.white,
      AdminButtonVariant.destructive => !isEnabled
          ? AdminColors.error.withAlpha(128)
          : _isPressed
              ? const Color(0xFF741515)
              : _isHovered
                  ? const Color(0xFFA52424)
                  : AdminColors.error,
      AdminButtonVariant.ghost => !isEnabled
          ? Colors.transparent
          : _isPressed
              ? const Color(0xFFF0EBE1)
              : _isHovered
                  ? AdminColors.surfaceSubtle
                  : Colors.transparent,
    };

    final Color fgColor = switch (widget.variant) {
      AdminButtonVariant.primary => AdminColors.white,
      AdminButtonVariant.secondary => isEnabled ? AdminColors.charcoal : AdminColors.muted,
      AdminButtonVariant.destructive => AdminColors.white,
      AdminButtonVariant.ghost => isEnabled ? AdminColors.charcoal : AdminColors.muted,
    };

    final Border? border = switch (widget.variant) {
      AdminButtonVariant.secondary => Border.all(
          color: _isFocused || _isHovered
              ? AdminColors.charcoal
              : AdminColors.line,
          width: 1.0,
        ),
      AdminButtonVariant.ghost => _isFocused
          ? Border.all(color: AdminColors.charcoal, width: 1.0)
          : null,
      _ => _isFocused
          ? Border.all(color: AdminColors.charcoal, width: 1.5)
          : null,
    };

    final content = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox.square(
            dimension: fontSize + 2,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: fgColor,
            ),
          ),
          const SizedBox(width: AdminSpacing.sm),
        ] else if (widget.icon != null) ...[
          IconTheme(
            data: IconThemeData(size: fontSize + 4, color: fgColor),
            child: widget.icon!,
          ),
          const SizedBox(width: AdminSpacing.sm),
        ],
        Text(
          widget.label,
          style: AdminTypography.button.copyWith(
            color: fgColor,
            fontSize: fontSize,
          ),
        ),
      ],
    );

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: MouseRegion(
        onEnter: (_) => isEnabled ? setState(() => _isHovered = true) : null,
        onExit: (_) => setState(() => _isHovered = false),
        cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapDown: (_) => isEnabled ? setState(() => _isPressed = true) : null,
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: isEnabled ? widget.onPressed : null,
          child: AnimatedContainer(
            duration: AdminMotion.duration(context, AdminMotion.hover),
            curve: AdminMotion.curveFast,
            height: height,
            padding: padding,
            decoration: BoxDecoration(
              color: bgColor,
              border: border,
              borderRadius: AdminRadii.radiusSm,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Refined icon button with subtle border, tooltip, and luxury hover effect.
class AdminIconButton extends StatefulWidget {
  const AdminIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = 38,
    this.bordered = true,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final bool bordered;

  @override
  State<AdminIconButton> createState() => _AdminIconButtonState();
}

class _AdminIconButtonState extends State<AdminIconButton> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    final bgColor = !isEnabled
        ? AdminColors.white.withAlpha(140)
        : _isPressed
            ? const Color(0xFFF0EBE1)
            : _isHovered
                ? AdminColors.surfaceSubtle
                : AdminColors.white;

    final borderColor = !isEnabled
        ? AdminColors.line.withAlpha(120)
        : _isFocused || _isHovered
            ? AdminColors.charcoal
            : AdminColors.line;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: Focus(
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        child: MouseRegion(
          onEnter: (_) => isEnabled ? setState(() => _isHovered = true) : null,
          onExit: (_) => setState(() => _isHovered = false),
          cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            onTapDown: (_) => isEnabled ? setState(() => _isPressed = true) : null,
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: AdminMotion.duration(context, AdminMotion.hover),
              curve: AdminMotion.curveFast,
              width: widget.size,
              height: widget.size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bgColor,
                border: widget.bordered
                    ? Border.all(color: borderColor, width: 1.0)
                    : null,
                borderRadius: AdminRadii.radiusSm,
              ),
              child: IconTheme(
                data: IconThemeData(
                  size: 18,
                  color: isEnabled ? AdminColors.charcoal : AdminColors.neutralGrey,
                ),
                child: widget.icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
