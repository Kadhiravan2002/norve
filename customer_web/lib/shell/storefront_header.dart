import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/bag/bag_provider.dart';

import '../app/breakpoints.dart';
import '../pages/shop_page.dart';

typedef StorefrontLink = ({String label, IconData icon, String route});

const newArrivalsRoute = '/?newArrivals=true';

/// The mobile app's five destinations, plus a direct link to New Arrivals.
const List<StorefrontLink> storefrontLinks = [
  (label: 'Home', icon: Icons.home_outlined, route: '/'),
  (label: 'Shop', icon: Icons.grid_view_outlined, route: '/shop'),
  (
    label: 'New Arrivals',
    icon: Icons.new_releases_outlined,
    route: newArrivalsRoute,
  ),
  (label: 'Wishlist', icon: Icons.favorite_border, route: '/wishlist'),
  (label: 'Bag', icon: Icons.shopping_bag_outlined, route: '/bag'),
  (label: 'Account', icon: Icons.person_outline, route: '/account'),
];

class StorefrontHeader extends StatelessWidget {
  const StorefrontHeader({super.key, this.showMenu = true, this.currentUri});

  /// False where no drawer exists, such as the standalone 404 page.
  final bool showMenu;

  /// Highlights the matching nav link. Null on pages outside the shell.
  final Uri? currentUri;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = StorefrontBreakpoints.gutter(width);
    final phone = StorefrontBreakpoints.isPhone(width);
    final desktop = StorefrontBreakpoints.isDesktop(width);
    final menu = showMenu && !desktop;
    final path = currentUri?.path;
    final showingNewArrivals =
        path == '/' && currentUri?.queryParameters['newArrivals'] == 'true';

    return Material(
      key: const ValueKey('storefront-header'),
      color: NorveColors.ivory,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: desktop ? 76 : 64,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: desktop ? gutter : (phone ? 4 : 16),
            ),
            child: desktop
                ? Row(
                    children: [
                      const _Wordmark(fontSize: 28),
                      const SizedBox(width: 48),
                      _NavText(
                        label: 'Home',
                        route: '/',
                        selected: path == '/' && !showingNewArrivals,
                      ),
                      _NavText(
                        label: 'Shop',
                        route: '/shop',
                        selected: path == '/shop',
                      ),
                      _NavText(
                        label: 'New Arrivals',
                        route: newArrivalsRoute,
                        selected: showingNewArrivals,
                      ),
                      const Spacer(),
                      const _SearchIcon(),
                      const _HeaderIcon(
                        icon: Icons.favorite_border,
                        label: 'Wishlist',
                        route: '/wishlist',
                      ),
                      const _HeaderIcon(
                        icon: Icons.person_outline,
                        label: 'Account',
                        route: '/account',
                      ),
                      const _BagIcon(),
                    ],
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      const _Wordmark(fontSize: 24),
                      Row(
                        children: [
                          if (menu)
                            Builder(
                              builder: (context) => IconButton(
                                key: const ValueKey('storefront-menu'),
                                tooltip: 'Menu',
                                icon: const Icon(Icons.menu, size: 22),
                                onPressed: () =>
                                    Scaffold.of(context).openDrawer(),
                              ),
                            ),
                          const Spacer(),
                          const _SearchIcon(),
                          const _BagIcon(),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    label: 'NORVÉ home',
    excludeSemantics: true,
    child: InkWell(
      key: const ValueKey('storefront-wordmark'),
      onTap: () => context.go('/'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          'NORVÉ',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: fontSize,
            letterSpacing: fontSize * 0.2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

class _NavText extends StatelessWidget {
  const _NavText({
    required this.label,
    required this.route,
    required this.selected,
  });

  final String label;
  final String route;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.go(route),
      style: TextButton.styleFrom(
        foregroundColor: selected ? NorveColors.charcoal : NorveColors.muted,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          letterSpacing: 0.6,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      child: Text(label),
    );
  }
}

class _SearchIcon extends StatelessWidget {
  const _SearchIcon();

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('storefront-search'),
    tooltip: 'Search',
    onPressed: () => context.go('/shop', extra: focusShopSearch),
    icon: const Icon(Icons.search, size: 21),
  );
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
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
  );
}

class _BagIcon extends ConsumerWidget {
  const _BagIcon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(bagItemCountProvider);
    return IconButton(
      key: const ValueKey('storefront-bag'),
      tooltip: 'Shopping bag',
      onPressed: () => context.go('/bag'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        backgroundColor: NorveColors.charcoal,
        textColor: NorveColors.white,
        child: const Icon(Icons.shopping_bag_outlined, size: 21),
      ),
    );
  }
}
