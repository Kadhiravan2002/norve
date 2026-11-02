import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/auth/application_role_provider.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/features/admin/admin_shell.dart';
import 'package:norve/features/navigation/administrator_web_access_screen.dart';
import 'package:norve/features/navigation/app_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('administrator is redirected away from customer only routes', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CustomerRouteGuard(
            child: Scaffold(body: Text('Customer checkout')),
          ),
        ),
        GoRoute(
          path: '/administrator-access',
          builder: (context, state) => const AdministratorWebAccessScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          applicationRoleProvider.overrideWithValue(
            const AsyncData(ApplicationRole.administrator),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Administration'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('administrator-sign-out')),
      findsOneWidget,
    );
    expect(find.text('Customer checkout'), findsNothing);
  });

  testWidgets('customer can continue to customer only routes', (tester) async {
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CustomerRouteGuard(
            child: Scaffold(body: Text('Customer checkout')),
          ),
        ),
        GoRoute(
          path: '/administrator-access',
          builder: (context, state) => const AdministratorWebAccessScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          applicationRoleProvider.overrideWithValue(
            const AsyncData(ApplicationRole.customer),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Customer checkout'), findsOneWidget);
    expect(find.text('Admin Dashboard'), findsNothing);
  });

  testWidgets('administrator shell shows only administrator navigation', (
    tester,
  ) async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final router = GoRouter(
      initialLocation: '/admin',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AdminShell(child: child),
          routes: [
            GoRoute(
              path: '/admin',
              builder: (context, state) =>
                  const Scaffold(body: Text('Admin Dashboard')),
            ),
            GoRoute(
              path: '/admin/products',
              builder: (context, state) =>
                  const Scaffold(body: Text('Admin Products')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          applicationRoleProvider.overrideWithValue(
            const AsyncData(ApplicationRole.administrator),
          ),
          supabaseClientProvider.overrideWithValue(client),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin Dashboard'), findsOneWidget);
    expect(find.text('ADMINISTRATION'), findsOneWidget);
    for (final customerDestination in [
      'Home',
      'Shop',
      'Wishlist',
      'Bag',
      'Account',
    ]) {
      expect(find.text(customerDestination), findsNothing);
    }
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.byTooltip('Sign Out'), findsOneWidget);
  });
}
