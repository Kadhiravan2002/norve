import 'package:flutter/material.dart';

import '../../../core/theme/norve_admin_tokens.dart';

/// Reusable content card for the NORVÉ administration platform.
///
/// Features a crisp white background with a subtle line border and minimal
/// 4px border radius, strictly avoiding heavy shadows and rounded pills.
class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.all(AdminSpacing.xl),
    this.headerPadding = const EdgeInsets.fromLTRB(
      AdminSpacing.xl,
      AdminSpacing.lg,
      AdminSpacing.xl,
      AdminSpacing.md,
    ),
    this.divider = true,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry headerPadding;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || subtitle != null || action != null;

    return Container(
      decoration: const BoxDecoration(
        color: AdminColors.white,
        border: AdminBorders.subtle,
        borderRadius: AdminRadii.radiusSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasHeader) ...[
            Padding(
              padding: headerPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            style: AdminTypography.cardTitle,
                          ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AdminSpacing.xxs),
                          Text(
                            subtitle!,
                            style: AdminTypography.caption,
                          ),
                        ],
                      ],
                    ),
                  ),
                  ?action,
                ],
              ),
            ),
            if (divider)
              const Divider(
                height: 1,
                thickness: 1,
                color: AdminColors.line,
              ),
          ],
          Padding(
            padding: padding,
            child: Material(
              type: MaterialType.transparency,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
