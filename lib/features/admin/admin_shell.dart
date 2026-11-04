import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/application_role_provider.dart';
import '../../core/supabase/backend_connection_provider.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/norve_admin_tokens.dart';
import '../../core/theme/norve_theme.dart';
import 'widgets/admin_buttons.dart';
import 'widgets/admin_feedback.dart';

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
    final userEmail = client.auth.currentUser?.email;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 768;
    final showAdminLabel = screenWidth >= 410;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            color: AdminColors.ivory,
            border: Border(
              bottom: AdminBorders.sideSubtle,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 20,
              ),
              child: Row(
                children: [
                  const Text(
                    'NORVÉ',
                    style: AdminTypography.brandTitle,
                  ),
                  if (showAdminLabel) ...[
                    Container(
                      width: 1,
                      height: 14,
                      color: AdminColors.line,
                      margin: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 14,
                      ),
                    ),
                    const Text(
                      'ADMINISTRATION',
                      style: AdminTypography.brandBadge,
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (userEmail != null) ...[
                          Flexible(
                            child: Tooltip(
                              message: userEmail,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: isMobile ? 220 : 280,
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 8 : 10,
                                  vertical: 4,
                                ),
                                decoration: const BoxDecoration(
                                  color: AdminColors.white,
                                  border: AdminBorders.subtle,
                                  borderRadius: AdminRadii.radiusSm,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AdminColors.success,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    SizedBox(width: isMobile ? 6 : 8),
                                    Flexible(
                                      child: Text(
                                        userEmail,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AdminTypography.caption.copyWith(
                                          color: AdminColors.charcoal,
                                          fontWeight: FontWeight.w500,
                                          fontSize: isMobile ? 11 : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: isMobile ? 8 : 12),
                        ],
                        AdminIconButton(
                          tooltip: 'Sign Out',
                          icon: const Icon(Icons.logout, size: 16),
                          size: 34,
                          onPressed: () async {
                            try {
                              await client.auth.signOut();
                              if (context.mounted) context.go(signOutLocation);
                            } catch (_) {
                              if (context.mounted) {
                                AdminSnackbar.show(
                                  context,
                                  message:
                                      'Sign out failed. Check your connection and try again.',
                                  isError: true,
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 768) return child;
          final isTabletSidebar = constraints.maxWidth < 1100;
          final sidebarWidth = isTabletSidebar ? 200.0 : 230.0;

          return Row(
            children: [
              Container(
                width: sidebarWidth,
                decoration: const BoxDecoration(
                  color: AdminColors.ivory,
                  border: Border(
                    right: AdminBorders.sideSubtle,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isTabletSidebar ? 16 : 20,
                        20,
                        isTabletSidebar ? 16 : 20,
                        8,
                      ),
                      child: const Text(
                        'MANAGEMENT',
                        style: AdminTypography.navGroup,
                      ),
                    ),
                    for (var i = 0; i < _routes.length; i++)
                      _AdminSidebarNavItem(
                        item: _routes[i],
                        isSelected: selectedIndex == i,
                        onTap: () => context.go(_routes[i].path),
                        compact: isTabletSidebar,
                      ),
                    const Spacer(),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AdminColors.line,
                    ),
                    Padding(
                      padding: EdgeInsets.all(isTabletSidebar ? 12 : 16),
                      child: const _BackendConnectionIndicator(),
                    ),
                  ],
                ),
              ),
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
          ? Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: AdminBorders.sideSubtle,
                ),
              ),
              child: NavigationBar(
                backgroundColor: AdminColors.ivory,
                surfaceTintColor: Colors.transparent,
                indicatorColor: NorveInteraction.selected,
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) =>
                    context.go(_routes[index].path),
                destinations: [
                  for (final item in _routes)
                    NavigationDestination(
                      icon: Icon(item.icon, size: 20),
                      selectedIcon: Icon(item.selected, size: 20),
                      label: item.label,
                    ),
                ],
              ),
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

class _AdminSidebarNavItem extends StatefulWidget {
  const _AdminSidebarNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
    this.compact = false,
  });

  final ({String label, IconData icon, IconData selected, String path}) item;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_AdminSidebarNavItem> createState() => _AdminSidebarNavItemState();
}

class _AdminSidebarNavItemState extends State<_AdminSidebarNavItem> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final fgColor = isSelected ? AdminColors.white : AdminColors.charcoal;
    final iconColor = isSelected ? AdminColors.white : AdminColors.muted;
    final bgColor = isSelected
        ? AdminColors.charcoal
        : _isPressed
            ? const Color(0xFFE8E2D9)
            : _isHovered
                ? NorveInteraction.hover
                : Colors.transparent;

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AdminMotion.duration(context, AdminMotion.hover),
            curve: AdminMotion.curveFast,
            height: 40,
            margin: EdgeInsets.symmetric(
              horizontal: widget.compact ? 8 : 12,
              vertical: 2,
            ),
            padding: EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 12),
            decoration: BoxDecoration(
              color: bgColor,
              border: _isFocused
                  ? Border.all(color: AdminColors.charcoal, width: 1.0)
                  : null,
              borderRadius: AdminRadii.radiusSm,
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? widget.item.selected : widget.item.icon,
                  size: 18,
                  color: iconColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.item.label,
                    overflow: TextOverflow.ellipsis,
                    style: AdminTypography.navItem.copyWith(
                      color: fgColor,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
                if (isSelected)
                  AnimatedContainer(
                    duration: AdminMotion.duration(context, AdminMotion.micro),
                    curve: AdminMotion.curveFast,
                    width: 3,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: AdminColors.white,
                      borderRadius: AdminRadii.radiusXs,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
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

class _BackendConnectionIndicator extends ConsumerWidget {
  const _BackendConnectionIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(backendConnectionProvider);

    return Tooltip(
      message: connection.tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        key: const ValueKey('backend-connection-indicator'),
        onTap: () =>
            ref.read(backendConnectionProvider.notifier).checkConnection(),
        borderRadius: AdminRadii.radiusSm,
        hoverColor: AdminColors.surfaceSubtle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            children: [
              AnimatedContainer(
                duration: AdminMotion.duration(context, AdminMotion.component),
                curve: AdminMotion.curveFast,
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: connection.dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  connection.label,
                  key: const ValueKey('backend-connection-label'),
                  overflow: TextOverflow.ellipsis,
                  style: AdminTypography.caption.copyWith(
                    color: AdminColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
