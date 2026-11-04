import 'package:flutter/material.dart';

import '../../../core/theme/norve_admin_tokens.dart';

enum AdminBadgeVariant {
  success,
  warning,
  error,
  info,
  draft,
  neutral,
}

/// Refined editorial status badge component.
///
/// Avoids neon pills by using soft matching tints, subtle borders, and
/// high-legibility dark typography.
class AdminBadge extends StatelessWidget {
  const AdminBadge({
    super.key,
    required this.label,
    this.variant = AdminBadgeVariant.neutral,
    this.showDot = false,
  });

  const AdminBadge.success({
    super.key,
    required this.label,
    this.showDot = false,
  }) : variant = AdminBadgeVariant.success;

  const AdminBadge.warning({
    super.key,
    required this.label,
    this.showDot = false,
  }) : variant = AdminBadgeVariant.warning;

  const AdminBadge.error({
    super.key,
    required this.label,
    this.showDot = false,
  }) : variant = AdminBadgeVariant.error;

  const AdminBadge.info({
    super.key,
    required this.label,
    this.showDot = false,
  }) : variant = AdminBadgeVariant.info;

  const AdminBadge.draft({
    super.key,
    required this.label,
    this.showDot = false,
  }) : variant = AdminBadgeVariant.draft;

  final String label;
  final AdminBadgeVariant variant;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final (textColor, bgColor, borderColor) = switch (variant) {
      AdminBadgeVariant.success => (
          AdminColors.success,
          AdminColors.successBg,
          AdminColors.successBorder,
        ),
      AdminBadgeVariant.warning => (
          AdminColors.warning,
          AdminColors.warningBg,
          AdminColors.warningBorder,
        ),
      AdminBadgeVariant.error => (
          AdminColors.error,
          AdminColors.errorBg,
          AdminColors.errorBorder,
        ),
      AdminBadgeVariant.info => (
          AdminColors.info,
          AdminColors.infoBg,
          AdminColors.infoBorder,
        ),
      AdminBadgeVariant.draft => (
          AdminColors.draft,
          AdminColors.draftBg,
          AdminColors.draftBorder,
        ),
      AdminBadgeVariant.neutral => (
          AdminColors.charcoal,
          AdminColors.white,
          AdminColors.line,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: AdminRadii.radiusXs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AdminSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AdminTypography.badge.copyWith(
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
