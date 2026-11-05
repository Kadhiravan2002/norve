import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/auth/auth_providers.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/features/account/account_screen.dart';
import 'package:norve/features/account/customer_order_details_screen.dart';
import 'package:norve/features/account/order_history_screen.dart';
import 'package:norve/features/account/password_reset_screen.dart';
import 'package:norve/features/bag/bag_screen.dart';
import 'package:norve/features/navigation/administrator_web_access_screen.dart';
import 'package:norve/features/orders/checkout_screen.dart';
import 'package:norve/features/wishlist/wishlist_screen.dart';

import '../catalog/catalog_query.dart';
import '../pages/home_page.dart';
import '../pages/not_found_page.dart';
import '../pages/product_route_page.dart';
import '../pages/shop_page.dart';
import '../shell/storefront_shell.dart';
import 'breakpoints.dart';
import 'route_guards.dart';

/// Existing mobile screens own their scrolling, so they are only width-capped.
Widget _capped(Widget child) => Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(
      maxWidth: StorefrontBreakpoints.contentMaxWidth,
    ),
    child: child,
  ),
);

final storefrontRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authSessionProvider, (_, _) => refresh.value++);
  ref.listen(adminAccessProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) => storefrontRedirect(
      state.uri,
      signedIn: ref.read(authRepositoryProvider).currentSession != null,
      isAdministrator: ref.read(adminAccessProvider).asData?.value,
    ),
    errorBuilder: (context, state) => const NotFoundPage(),
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            StorefrontShell(currentUri: state.uri, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => HomePage(
              location: state.uri.toString(),
              selectedCategoryId: state.uri.queryParameters['categoryId'],
              newArrivals: state.uri.queryParameters['newArrivals'] == 'true',
            ),
          ),
          GoRoute(
            path: '/shop',
            builder: (context, state) => ShopPage(
              location: state.uri.toString(),
              query: CatalogQuery.fromUri(state.uri),
              focusSearch: state.extra == focusShopSearch,
            ),
          ),
          GoRoute(
            path: '/product/:productId',
            builder: (context, state) =>
                ProductRoutePage(productId: state.pathParameters['productId']!),
          ),
          GoRoute(
            path: '/wishlist',
            builder: (context, state) => _capped(const WishlistScreen()),
          ),
          GoRoute(
            path: '/bag',
            builder: (context, state) => _capped(const BagScreen()),
          ),
          GoRoute(
            path: '/account',
            builder: (context, state) => _capped(const AccountScreen()),
          ),
          GoRoute(
            path: '/account/orders',
            builder: (context, state) => _capped(const OrderHistoryScreen()),
          ),
          GoRoute(
            path: '/account/orders/:orderId',
            builder: (context, state) => _capped(
              CustomerOrderDetailsScreen(
                orderId: state.pathParameters['orderId']!,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/account/reset-password',
        builder: (context, state) => const PasswordResetScreen(),
      ),
      GoRoute(
        path: '/administrator-access',
        builder: (context, state) => const AdministratorWebAccessScreen(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
