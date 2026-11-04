import 'package:flutter/material.dart';

import '../../../core/theme/norve_admin_tokens.dart';

/// Standardized luxury editorial page header for the NORVÉ administration platform.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.breadcrumbs,
    this.padding = const EdgeInsets.fromLTRB(24, 28, 24, 20),
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? breadcrumbs;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;

          final titleSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AdminTypography.pageTitle,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: AdminTypography.pageSubtitle,
                ),
              ],
            ],
          );

          final actionsSection = (actions != null && actions!.isNotEmpty)
              ? Wrap(
                  spacing: AdminSpacing.md,
                  runSpacing: AdminSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions!,
                )
              : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (breadcrumbs != null) ...[
                breadcrumbs!,
                const SizedBox(height: AdminSpacing.sm),
              ],
              if (isCompact) ...[
                titleSection,
                if (actionsSection != null) ...[
                  const SizedBox(height: AdminSpacing.md),
                  actionsSection,
                ],
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: titleSection),
                    if (actionsSection != null) ...[
                      const SizedBox(width: AdminSpacing.lg),
                      actionsSection,
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
