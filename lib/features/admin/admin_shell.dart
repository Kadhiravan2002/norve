import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/application_role_provider.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/norve_theme.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({
    super.key,
    required this.child,
    this.unauthorizedLocation = '/account',
    this.signOutLocation = '/account',
  });

  final Widget child;
  final String unauthorizedLocation;
  final String signOutLocation;

  static const _routes = [
    (
      label: 'Dashboard',
      icon: Icons.space_dashboard_outlined,
      selected: Icons.space_dashboard,
      path: '/admin',
    ),
    (
      label: 'Products',
      icon: Icons.inventory_2_outlined,
      selected: Icons.inventory_2,
      path: '/admin/products',
    ),
    (
      label: 'Orders',
      icon: Icons.receipt_long_outlined,
      selected: Icons.receipt_long,
      path: '/admin/orders',
    ),
    (
      label: 'Inventory',
      icon: Icons.stacked_bar_chart_outlined,
      selected: Icons.stacked_bar_chart,
      path: '/admin/inventory',
    ),
    (
      label: 'Categories',
      icon: Icons.category_outlined,
      selected: Icons.category,
      path: '/admin/categories',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);
    return ref
        .watch(applicationRoleProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stackTrace) => const _RouteRedirect('/admin/sign-in'),
          data: (role) {
            if (role == ApplicationRole.administrator && client != null) {
              return _buildShell(context, client, ref);
            }
            return _RouteRedirect(
              role == ApplicationRole.signedOut
                  ? '/admin/sign-in'
                  : unauthorizedLocation,
            );
          },
        );
  }

  Widget _buildShell(
    BuildContext context,
    SupabaseClient client,
    WidgetRef ref,
  ) {
    final path = GoRouterState.of(context).uri.path;
    final selectedIndex = _selectedIndex(path);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'NORVÉ',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(letterSpacing: 3.2),
            ),
            const SizedBox(width: 10),
            Text(
              'ADMINISTRATION',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(letterSpacing: 1.2),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            onPressed: () async {
              try {
                await client.auth.signOut();
                if (context.mounted) context.go(signOutLocation);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Sign out failed. Check your connection and try again.',
                      ),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 768) return child;
          return Row(
            children: [
              NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) =>
                    context.go(_routes[index].path),
                labelType: NavigationRailLabelType.all,
                backgroundColor: NorveColors.ivory,
                destinations: [
                  for (final item in _routes)
                    NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selected),
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
          );
        },
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 768
          ? NavigationBar(
              backgroundColor: NorveColors.ivory,
              surfaceTintColor: Colors.transparent,
              indicatorColor: NorveInteraction.selected,
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => context.go(_routes[index].path),
              destinations: [
                for (final item in _routes)
                  NavigationDestination(
                    icon: Icon(item.icon, size: 20),
                    selectedIcon: Icon(item.selected, size: 20),
                    label: item.label,
                  ),
              ],
            )
          : null,
    );
  }

  int _selectedIndex(String path) {
    if (path.startsWith('/admin/products')) return 1;
    if (path.startsWith('/admin/orders')) return 2;
    if (path.startsWith('/admin/inventory')) return 3;
    if (path.startsWith('/admin/categories')) return 4;
    return 0;
  }
}

class _RouteRedirect extends StatefulWidget {
  const _RouteRedirect(this.location);

  final String location;

  @override
  State<_RouteRedirect> createState() => _RouteRedirectState();
}

class _RouteRedirectState extends State<_RouteRedirect> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GoRouter.of(context).go(widget.location);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
