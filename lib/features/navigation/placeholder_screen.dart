import 'package:flutter/material.dart';

import '../../core/theme/norve_theme.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'NORVÉ',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(letterSpacing: 4, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 30),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: NorveColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
