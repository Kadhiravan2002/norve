import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/norve_theme.dart';

class StoreHeader extends StatelessWidget {
  const StoreHeader({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 10, 4),
    child: Column(
      children: [
        Row(
          children: [
            const SizedBox(
              width: 84,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _HeaderAction(
                  icon: Icons.search,
                  label: 'Search',
                  route: '/shop',
                ),
              ),
            ),
            Expanded(
              child: Text(
                'NORVÉ',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 26,
                  letterSpacing: 5.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(
              width: 84,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  _HeaderAction(
                    icon: Icons.favorite_border,
                    label: 'Wishlist',
                    route: '/wishlist',
                  ),
                  _HeaderAction(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Shopping bag',
                    route: '/bag',
                  ),
                ],
              ),
            ),
          ],
        ),
        Text(
          'E L E V A T E   Y O U R   E V E R Y D A Y',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 8,
            letterSpacing: 0.65,
            color: NorveColors.muted,
          ),
        ),
      ],
    ),
  );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: () => context.go(route),
    icon: Icon(icon, size: 21),
    visualDensity: VisualDensity.compact,
  );
}
