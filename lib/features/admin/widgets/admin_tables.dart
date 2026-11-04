import 'package:flutter/material.dart';

import '../../../core/theme/norve_admin_tokens.dart';

/// Clean data table wrapper adhering to NORVÉ's luxury editorial design.
class AdminTable extends StatelessWidget {
  const AdminTable({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AdminColors.white,
        border: AdminBorders.subtle,
        borderRadius: AdminRadii.radiusSm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

/// Header row for administration tables.
class AdminTableHeader extends StatelessWidget {
  const AdminTableHeader({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AdminSpacing.lg,
      vertical: AdminSpacing.md,
    ),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        color: AdminColors.surfaceSubtle,
        border: Border(
          bottom: AdminBorders.sideSubtle,
        ),
      ),
      child: Row(
        children: children,
      ),
    );
  }
}

/// Header cell with uppercase letter-spaced muted typography.
class AdminTableHeaderCell extends StatelessWidget {
  const AdminTableHeaderCell({
    super.key,
    required this.label,
    this.flex = 1,
    this.width,
    this.alignment = Alignment.centerLeft,
  });

  final String label;
  final int flex;
  final double? width;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final text = Align(
      alignment: alignment,
      child: Text(
        label.toUpperCase(),
        style: AdminTypography.tableHeader,
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: text);
    }
    return Expanded(flex: flex, child: text);
  }
}

/// Interactive table data row with subtle hover state.
class AdminTableRow extends StatefulWidget {
  const AdminTableRow({
    super.key,
    required this.children,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AdminSpacing.lg,
      vertical: AdminSpacing.md,
    ),
    this.showDivider = true,
  });

  final List<Widget> children;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool showDivider;

  @override
  State<AdminTableRow> createState() => _AdminTableRowState();
}

class _AdminTableRowState extends State<AdminTableRow> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isClickable = widget.onTap != null;

    final bgColor = isClickable && _isPressed
        ? const Color(0xFFF0EBE1)
        : isClickable && _isHovered
            ? AdminColors.surfaceSubtle
            : AdminColors.white;

    return MouseRegion(
      onEnter: (_) => isClickable ? setState(() => _isHovered = true) : null,
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isClickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) => isClickable ? setState(() => _isPressed = true) : null,
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AdminMotion.duration(context, AdminMotion.hover),
          curve: AdminMotion.curveFast,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: bgColor,
            border: widget.showDivider
                ? const Border(bottom: AdminBorders.sideSubtle)
                : null,
          ),
          child: Row(
            children: widget.children,
          ),
        ),
      ),
    );
  }
}

/// Table cell wrapper with flex / width alignment.
class AdminTableCell extends StatelessWidget {
  const AdminTableCell({
    super.key,
    required this.child,
    this.flex = 1,
    this.width,
    this.alignment = Alignment.centerLeft,
  });

  final Widget child;
  final int flex;
  final double? width;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final aligned = Align(alignment: alignment, child: child);
    if (width != null) {
      return SizedBox(width: width, child: aligned);
    }
    return Expanded(flex: flex, child: aligned);
  }
}
