import 'package:flutter/material.dart';

import '../../../core/theme/norve_admin_tokens.dart';

/// Architectural 1px horizontal divider.
class AdminDivider extends StatelessWidget {
  const AdminDivider({
    super.key,
    this.color = AdminColors.line,
    this.height = 1,
    this.thickness = 1,
    this.indent,
    this.endIndent,
  });

  final Color color;
  final double height;
  final double thickness;
  final double? indent;
  final double? endIndent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: height,
      thickness: thickness,
      color: color,
      indent: indent,
      endIndent: endIndent,
    );
  }
}

/// Architectural 1px vertical divider.
class AdminVerticalDivider extends StatelessWidget {
  const AdminVerticalDivider({
    super.key,
    this.color = AdminColors.line,
    this.width = 1,
    this.thickness = 1,
  });

  final Color color;
  final double width;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: width,
      thickness: thickness,
      color: color,
    );
  }
}
