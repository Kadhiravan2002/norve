import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/norve_theme.dart';
import '../core/auth/auth_providers.dart';
import '../core/auth/application_role_provider.dart';
import '../features/navigation/placeholder_screen.dart';
import '../features/navigation/administrator_web_access_screen.dart';
import '../features/account/account_screen.dart';
import '../features/account/order_history_screen.dart';
import '../features/account/password_reset_screen.dart';
import '../features/bag/bag_screen.dart';
import '../features/products/product_catalog_provider.dart';
import '../features/products/product_details_screen.dart';
import '../features/products/home_screen.dart';
import '../features/products/shop_screen.dart';
import '../features/orders/checkout_screen.dart';
import '../features/account/customer_order_details_screen.dart';
import '../features/wishlist/wishlist_screen.dart';
import '../features/bag/bag_provider.dart';
import '../features/wishlist/wishlist_provider.dart';
import '../features/orders/order_providers.dart';
import '../features/account/customer_data_providers.dart';
import '../features/navigation/app_shell.dart';

GoRouter createNorveRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  redirect: (context, state) {
    final path = state.uri.path;
    return path == '/admin' || path.startsWith('/admin/')
        ? '/administrator-access'
        : null;
  },
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => HomeScreen(
            selectedCategoryId: state.uri.queryParameters['categoryId'],
            newArrivals: state.uri.queryParameters['newArrivals'] == 'true',
          ),
        ),
        GoRoute(
          path: '/shop',
          builder: (context, state) => ShopScreen(
            selectedCategoryId: state.uri.queryParameters['categoryId'],
          ),
        ),
        GoRoute(
          path: '/wishlist',
          builder: (context, state) => const WishlistScreen(),
        ),
        GoRoute(path: '/bag', builder: (context, state) => const BagScreen()),
        GoRoute(
          path: '/account',
          builder: (context, state) => const AccountScreen(),
        ),
        GoRoute(
          path: '/account/orders',
          builder: (context, state) => const OrderHistoryScreen(),
        ),
        GoRoute(
          path: '/account/orders/:orderId',
          builder: (context, state) => CustomerOrderDetailsScreen(
            orderId: state.pathParameters['orderId']!,
          ),
        ),
        GoRoute(
          path: '/account/reset-password',
          builder: (context, state) => const PasswordResetScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/product/:productId',
      builder: (context, state) {
        final productId = state.pathParameters['productId'];
        return CustomerRouteGuard(
          child: _ProductDetailsRoute(productId: productId ?? ''),
        );
      },
    ),
    GoRoute(
      path: '/checkout',
      builder: (context, state) =>
          const CustomerRouteGuard(child: CheckoutScreen()),
    ),
    GoRoute(
      path: '/administrator-access',
      builder: (context, state) => const AdministratorWebAccessScreen(),
    ),
  ],
);

class _ProductDetailsRoute extends ConsumerWidget {
  const _ProductDetailsRoute({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(catalogLoadStateProvider);
    final matches = ref.watch(
      productCatalogProvider.select(
        (catalog) => catalog.where((item) => item.id == productId),
      ),
    );
    if (status.phase == CatalogPhase.loading && matches.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (status.phase == CatalogPhase.error && matches.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(status.message ?? 'Catalogue unavailable.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.read(productCatalogProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (matches.isEmpty) {
      return const PlaceholderScreen(
        title: 'Product unavailable',
        subtitle: 'This piece is no longer available.',
      );
    }
    final product = matches.first;
    if (!product.isActive) {
      return const PlaceholderScreen(
        title: 'Product unavailable',
        subtitle: 'This piece is not currently available.',
      );
    }
    return ProductDetailsScreen(key: ValueKey(product.id), product: product);
  }
}

class NorveApp extends ConsumerStatefulWidget {
  const NorveApp({super.key, this.initialLocation = '/', this.router});

  final String initialLocation;
  final GoRouter? router;

  @override
  ConsumerState<NorveApp> createState() => _NorveAppState();
}

class _NorveAppState extends ConsumerState<NorveApp> {
  late final GoRouter _router;
  ApplicationRole? _lastResolvedRole;
  bool _initialRoleResolved = false;

  @override
  void initState() {
    super.initState();
    _router =
        widget.router ??
        createNorveRouter(initialLocation: widget.initialLocation);
  }

  @override
  void dispose() {
    if (widget.router == null) _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider, (previous, next) {
      final oldId = previous?.asData?.value?.userId;
      final nextId = next.asData?.value?.userId;
      if (oldId != null && oldId != nextId) {
        ref.read(bagProvider.notifier).clear();
        ref.read(wishlistProvider.notifier).clear();
        ref.read(checkoutControllerProvider.notifier).reset();
        ref.invalidate(customerProfileProvider(oldId));
        ref.invalidate(customerAddressesProvider(oldId));
        ref.invalidate(customerOrdersProvider);
        ref.invalidate(customerOrderProvider);
        ref.invalidate(adminOrdersProvider);
        ref.invalidate(adminOrderSummaryProvider);
      }
    });
    ref.listen(applicationRoleProvider, (previous, next) {
      final role = next.asData?.value;
      if (role == null) return;

      final previousRole = _lastResolvedRole;
      _lastResolvedRole = role;
      final currentPath = _router.routeInformationProvider.value.uri.path;
      String? destination;

      if (!_initialRoleResolved) {
        _initialRoleResolved = true;
        destination = switch (role) {
          ApplicationRole.administrator => '/administrator-access',
          ApplicationRole.customer =>
            currentPath == '/account/reset-password' ? null : '/',
          ApplicationRole.signedOut =>
            currentPath == '/admin/sign-in' || currentPath == '/account'
                ? null
                : '/account',
        };
      } else {
        destination = switch (role) {
          ApplicationRole.administrator =>
            previousRole == ApplicationRole.administrator
                ? null
                : '/administrator-access',
          ApplicationRole.customer =>
            previousRole == ApplicationRole.signedOut &&
                    currentPath == '/account'
                ? '/'
                : null,
          ApplicationRole.signedOut =>
            previousRole != null &&
                    previousRole != ApplicationRole.signedOut &&
                    currentPath != '/account'
                ? '/account'
                : null,
        };
      }

      if (destination == null || destination == currentPath) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _lastResolvedRole != role ||
            _router.routeInformationProvider.value.uri.path != currentPath) {
          return;
        }
        _router.go(destination!);
      });
    });
    return MaterialApp.router(
      title: 'NORVÉ — Elevate Your Everyday',
      debugShowCheckedModeBanner: false,
      theme: NorveTheme.light,
      routerConfig: _router,
    );
  }
}
