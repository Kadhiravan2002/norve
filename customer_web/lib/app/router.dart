import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/auth/auth_providers.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/features/account/customer_order_details_screen.dart';
import 'package:norve/features/account/order_history_screen.dart';
import 'package:norve/features/navigation/administrator_web_access_screen.dart';

import '../catalog/catalog_query.dart';
import '../pages/account_page.dart';
import '../pages/auth_page.dart';
import '../pages/bag_page.dart';
import '../pages/checkout_page.dart';
import '../pages/home_page.dart';
import '../pages/not_found_page.dart';
import '../pages/password_reset_page.dart';
import '../pages/product_route_page.dart';
import '../pages/shop_page.dart';
import '../pages/wishlist_page.dart';
import '../shell/storefront_shell.dart';
import '../widgets/back_link_frame.dart';
import '../widgets/refresh_orders_on_open.dart';
import 'route_guards.dart';

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
            builder: (context, state) => const WishlistPage(),
          ),
          GoRoute(path: '/bag', builder: (context, state) => const BagPage()),
          GoRoute(
            path: loginPath,
            builder: (context, state) => AuthPage(
              mode: AuthPageMode.signIn,
              returnPath: state.uri.queryParameters['from'],
            ),
          ),
          GoRoute(
            path: registerPath,
            builder: (context, state) => AuthPage(
              mode: AuthPageMode.register,
              returnPath: state.uri.queryParameters['from'],
            ),
          ),
          GoRoute(
            path: accountPath,
            builder: (context, state) => const AccountPage(),
          ),
          GoRoute(
            path: '/account/orders',
            builder: (context, state) => const BackLinkFrame(
              label: 'Account',
              route: accountPath,
              child: RefreshOrdersOnOpen(child: OrderHistoryScreen()),
            ),
          ),
          GoRoute(
            path: '/account/orders/:orderId',
            builder: (context, state) => BackLinkFrame(
              label: 'Your Orders',
              route: '/account/orders',
              child: RefreshOrdersOnOpen(
                orderId: state.pathParameters['orderId'],
                child: CustomerOrderDetailsScreen(
                  orderId: state.pathParameters['orderId']!,
                ),
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutPage(),
      ),
      GoRoute(
        path: passwordResetPath,
        builder: (context, state) => const PasswordResetPage(),
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
