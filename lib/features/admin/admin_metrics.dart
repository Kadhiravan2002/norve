import 'package:flutter/material.dart';

import '../../core/theme/norve_admin_tokens.dart';

const lowStockThreshold = 5;

/// Luxury metric presentation card for the NORVÉ administration platform.
class AdminMetricCard extends StatelessWidget {
  const AdminMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AdminSpacing.xl),
        decoration: const BoxDecoration(
          color: AdminColors.white,
          border: AdminBorders.subtle,
          borderRadius: AdminRadii.radiusSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AdminTypography.caption.copyWith(
                color: AdminColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AdminSpacing.md),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                color: AdminColors.charcoal,
              ),
            ),
            const SizedBox(height: AdminSpacing.xs),
            Text(
              caption,
              style: AdminTypography.caption.copyWith(
                color: AdminColors.neutralGrey,
              ),
            ),
          ],
        ),
      );
}

/// Refined status chip component preserved for backwards compatibility.
class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: const BoxDecoration(
          color: AdminColors.white,
          border: AdminBorders.subtle,
          borderRadius: AdminRadii.radiusXs,
        ),
        child: Text(
          label,
          style: AdminTypography.badge.copyWith(
            fontSize: 10,
            color: AdminColors.charcoal,
          ),
        ),
      );
}
