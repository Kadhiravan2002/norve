import 'package:flutter/material.dart';

import '../../core/theme/norve_theme.dart';

const lowStockThreshold = 5;

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
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: NorveColors.white,
      border: Border.all(color: NorveColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: NorveColors.muted),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: NorveColors.muted),
        ),
      ],
    ),
  );
}

class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: NorveColors.white,
      border: Border.all(color: NorveColors.line),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
    ),
  );
}
