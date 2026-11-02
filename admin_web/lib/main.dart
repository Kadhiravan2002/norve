import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/auth/auth_providers.dart';
import 'package:norve/core/supabase/supabase_config.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/admin/admin_categories_screen.dart';
import 'package:norve/features/admin/admin_dashboard_screen.dart';
import 'package:norve/features/admin/admin_inventory_screen.dart';
import 'package:norve/features/admin/admin_order_details_screen.dart';
import 'package:norve/features/admin/admin_orders_screen.dart';
import 'package:norve/features/admin/admin_product_form_screen.dart';
import 'package:norve/features/admin/admin_products_screen.dart';
import 'package:norve/features/admin/admin_shell.dart';
import 'package:norve/features/admin/admin_sign_in_screen.dart';
import 'package:norve/features/orders/order_providers.dart';
import 'package:norve/features/products/product_catalog_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = SupabaseConfig.fromEnvironment();
  SupabaseClient? client;
  String? startupError;
  if (config.isConfigured) {
    try {
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.publishableKey,
      );
      client = Supabase.instance.client;
    } catch (_) {
      startupError = 'Supabase could not be initialized. Check the project URL, publishable key, and network connection.';
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        supabaseConfigProvider.overrideWithValue(config),
        supabaseClientProvider.overrideWithValue(client),
        supabaseStartupErrorProvider.overrideWithValue(startupError),
      ],
      child: const NorveAdminWebApp(),
    ),
  );
}

GoRouter createAdminWebRouter({String initialLocation = '/admin'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) => '/admin',
    ),
    GoRoute(
      path: '/admin/sign-in',
      builder: (context, state) => const AdminSignInScreen(
        customerReturnLocation: null,
        showBackButton: false,
      ),
    ),
    ShellRoute(
      builder: (context, state, child) => AdminShell(
        unauthorizedLocation: '/admin/sign-in',
        signOutLocation: '/admin/sign-in',
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: '/admin/products',
          builder: (context, state) => const AdminProductsScreen(),
        ),
        GoRoute(
          path: '/admin/products/new',
          builder: (context, state) => const AdminProductFormScreen(),
        ),
        GoRoute(
          path: '/admin/products/:productId/edit',
          builder: (context, state) => AdminProductFormScreen(
            productId: state.pathParameters['productId'],
          ),
        ),
        GoRoute(
          path: '/admin/orders',
          builder: (context, state) => const AdminOrdersScreen(),
        ),
        GoRoute(
          path: '/admin/orders/:orderId',
          builder: (context, state) => AdminOrderDetailsScreen(
            orderId: state.pathParameters['orderId']!,
          ),
        ),
        GoRoute(
          path: '/admin/inventory',
          builder: (context, state) => const AdminInventoryScreen(),
        ),
        GoRoute(
          path: '/admin/categories',
          builder: (context, state) => const AdminCategoriesScreen(),
        ),
      ],
    ),
  ],
);

class NorveAdminWebApp extends ConsumerStatefulWidget {
  const NorveAdminWebApp({super.key});

  @override
  ConsumerState<NorveAdminWebApp> createState() => _NorveAdminWebAppState();
}

class _NorveAdminWebAppState extends ConsumerState<NorveAdminWebApp> {
  late final GoRouter _router = createAdminWebRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider, (previous, next) {
      final oldId = previous?.asData?.value?.userId;
      final nextId = next.asData?.value?.userId;
      if (oldId != null && oldId != nextId) {
        ref.invalidate(productCatalogProvider);
        ref.invalidate(adminOrdersProvider);
        ref.invalidate(adminOrderProvider);
        ref.invalidate(adminOrderSummaryProvider);
      }
    });
    return MaterialApp.router(
      title: 'NORVÉ Administration',
      theme: NorveTheme.light,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
