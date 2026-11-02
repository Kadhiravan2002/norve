import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/application_role_provider.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/theme/norve_theme.dart';
import '../bag/bag_provider.dart';

/// Guards customer-only destinations that do not live inside [AppShell].
class CustomerRouteGuard extends ConsumerWidget {
  const CustomerRouteGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(applicationRoleProvider)
      .when(
        loading: _loading,
        error: (error, stackTrace) => const _RoleError(),
        data: (role) {
          if (role == ApplicationRole.administrator) {
            return const _RoleRedirect('/administrator-access');
          }
          return child;
        },
      );
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _destinations = [
    (
      label: 'Home',
      icon: Icons.home_outlined,
      selected: Icons.home_filled,
      route: '/',
    ),
    (
      label: 'Shop',
      icon: Icons.grid_view_outlined,
      selected: Icons.grid_view_rounded,
      route: '/shop',
    ),
    (
      label: 'Wishlist',
      icon: Icons.favorite_border,
      selected: Icons.favorite,
      route: '/wishlist',
    ),
    (
      label: 'Bag',
      icon: Icons.shopping_bag_outlined,
      selected: Icons.shopping_bag,
      route: '/bag',
    ),
    (
      label: 'Account',
      icon: Icons.person_outline,
      selected: Icons.person,
      route: '/account',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleState = ref.watch(applicationRoleProvider);
    return roleState.when(
      loading: _loading,
      error: (error, stackTrace) => const _RoleError(),
      data: (role) {
        if (role == ApplicationRole.administrator) {
          return const _RoleRedirect('/administrator-access');
        }
        ref.listen(authEventsProvider, (previous, next) {
          if (next.asData?.value == AuthChangeEvent.passwordRecovery) {
            context.go('/account/reset-password');
          }
        });
        final location = GoRouterState.of(context).uri.path;
        final selectedIndex = _destinations.indexWhere(
          (item) => item.route == location,
        );
        final bagCount = ref.watch(bagItemCountProvider);
        final wide = MediaQuery.sizeOf(context).width >= 1024;
        return Scaffold(
          body: wide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
                      onDestinationSelected: (index) =>
                          context.go(_destinations[index].route),
                      labelType: NavigationRailLabelType.all,
                      backgroundColor: NorveColors.ivory,
                      indicatorColor: NorveColors.charcoal.withValues(
                        alpha: 0.08,
                      ),
                      destinations: [
                        for (final item in _destinations)
                          NavigationRailDestination(
                            icon: _icon(
                              item.icon,
                              item.label == 'Bag' ? bagCount : 0,
                            ),
                            selectedIcon: _icon(
                              item.selected,
                              item.label == 'Bag' ? bagCount : 0,
                            ),
                            label: Text(item.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1440),
                          child: child,
                        ),
                      ),
                    ),
                  ],
                )
              : child,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  backgroundColor: NorveColors.ivory,
                  surfaceTintColor: Colors.transparent,
                  indicatorColor: NorveColors.charcoal.withValues(alpha: 0.08),
                  elevation: 0,
                  height: 64,
                  selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
                  onDestinationSelected: (index) =>
                      context.go(_destinations[index].route),
                  destinations: [
                    for (final item in _destinations)
                      NavigationDestination(
                        icon: _icon(
                          item.icon,
                          item.label == 'Bag' ? bagCount : 0,
                        ),
                        selectedIcon: _icon(
                          item.selected,
                          item.label == 'Bag' ? bagCount : 0,
                        ),
                        label: item.label,
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _icon(IconData icon, int badgeCount) => Badge(
    isLabelVisible: badgeCount > 0,
    label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
    backgroundColor: NorveColors.charcoal,
    textColor: NorveColors.white,
    child: Icon(icon, size: 20),
  );
}

Widget _loading() =>
    const Scaffold(body: Center(child: CircularProgressIndicator()));

class _RoleError extends StatelessWidget {
  const _RoleError();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your access could not be verified.'),
            TextButton(
              onPressed: () => context.go('/account'),
              child: const Text('Continue to account'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoleRedirect extends StatefulWidget {
  const _RoleRedirect(this.location);
  final String location;

  @override
  State<_RoleRedirect> createState() => _RoleRedirectState();
}

class _RoleRedirectState extends State<_RoleRedirect> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(widget.location);
    });
  }

  @override
  Widget build(BuildContext context) => _loading();
}
