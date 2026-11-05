import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/theme/norve_theme.dart';

import '../app/breakpoints.dart';

/// Places the footer at the end of a page, and at the bottom of a short one.
class StorefrontFooterSliver extends StatelessWidget {
  const StorefrontFooterSliver({super.key});

  @override
  Widget build(BuildContext context) => const SliverFillRemaining(
    hasScrollBody: false,
    child: Align(alignment: Alignment.bottomCenter, child: StorefrontFooter()),
  );
}

class StorefrontFooter extends StatelessWidget {
  const StorefrontFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final phone = StorefrontBreakpoints.isPhone(width);
    final gutter = StorefrontBreakpoints.gutter(width);
    final textTheme = Theme.of(context).textTheme;

    final brand = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NORVÉ',
          style: textTheme.titleLarge?.copyWith(
            color: NorveColors.ivory,
            fontSize: 26,
            letterSpacing: 5.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'ELEVATE YOUR EVERYDAY',
          style: textTheme.labelSmall?.copyWith(
            color: NorveColors.line,
            letterSpacing: 2.2,
          ),
        ),
      ],
    );
    const shop = _FooterColumn(
      title: 'SHOP',
      links: [
        (label: 'All products', route: '/shop'),
        (label: 'New arrivals', route: '/?newArrivals=true'),
        (label: 'Wishlist', route: '/wishlist'),
        (label: 'Bag', route: '/bag'),
      ],
    );
    const account = _FooterColumn(
      title: 'ACCOUNT',
      links: [
        (label: 'Your account', route: '/account'),
        (label: 'Your orders', route: '/account/orders'),
      ],
    );

    return Container(
      key: const ValueKey('storefront-footer'),
      width: double.infinity,
      color: NorveColors.charcoal,
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, 48, gutter, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (phone) ...[
              brand,
              const SizedBox(height: 32),
              shop,
              const SizedBox(height: 28),
              account,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: brand),
                  const Expanded(child: shop),
                  const Expanded(child: account),
                ],
              ),
            const SizedBox(height: 36),
            Text(
              '© ${DateTime.now().year} NORVÉ',
              style: textTheme.bodySmall?.copyWith(color: NorveColors.line),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.links});

  final String title;
  final List<({String label, String route})> links;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: NorveColors.line, letterSpacing: 1.6),
      ),
      const SizedBox(height: 10),
      for (final link in links)
        TextButton(
          onPressed: () => context.go(link.route),
          style: TextButton.styleFrom(
            foregroundColor: NorveColors.ivory,
            padding: const EdgeInsets.symmetric(vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(link.label),
        ),
    ],
  );
}
