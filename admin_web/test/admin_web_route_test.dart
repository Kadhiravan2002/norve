import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/core/auth/application_role_provider.dart';
import 'package:norve/core/supabase/supabase_config.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve_admin_web/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('missing Supabase configuration fails closed on admin route', (
    tester,
  ) async {
    final router = createAdminWebRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfigProvider.overrideWithValue(
            const SupabaseConfig(url: '', publishableKey: ''),
          ),
          supabaseClientProvider.overrideWithValue(null),
          supabaseStartupErrorProvider.overrideWithValue(null),
        ],
        child: MaterialApp.router(
          theme: NorveTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin Sign In'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('admin-auth-configuration-state')),
      findsOneWidget,
    );
    expect(find.text('Admin Dashboard'), findsNothing);
  });

  testWidgets('customer membership is redirected away from admin shell', (
    tester,
  ) async {
    final router = createAdminWebRouter(initialLocation: '/admin/products');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          applicationRoleProvider.overrideWithValue(
            const AsyncData(ApplicationRole.customer),
          ),
          supabaseConfigProvider.overrideWithValue(
            const SupabaseConfig(url: '', publishableKey: ''),
          ),
          supabaseClientProvider.overrideWithValue(null),
          supabaseStartupErrorProvider.overrideWithValue(null),
        ],
        child: MaterialApp.router(
          theme: NorveTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin Sign In'), findsOneWidget);
    expect(find.text('Products'), findsNothing);
    expect(find.text('ADMINISTRATION'), findsNothing);
  });

  testWidgets('visiting root path / redirects unauthenticated user to admin sign in', (
    tester,
  ) async {
    final router = createAdminWebRouter(initialLocation: '/');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          applicationRoleProvider.overrideWithValue(
            const AsyncData(ApplicationRole.signedOut),
          ),
          supabaseConfigProvider.overrideWithValue(
            const SupabaseConfig(url: '', publishableKey: ''),
          ),
          supabaseClientProvider.overrideWithValue(null),
          supabaseStartupErrorProvider.overrideWithValue(null),
        ],
        child: MaterialApp.router(
          theme: NorveTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin Sign In'), findsOneWidget);
    expect(find.text('Admin Dashboard'), findsNothing);
  });

  testWidgets('visiting root path / redirects administrator to admin dashboard', (
    tester,
  ) async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final router = createAdminWebRouter(initialLocation: '/');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          applicationRoleProvider.overrideWithValue(
            const AsyncData(ApplicationRole.administrator),
          ),
          supabaseConfigProvider.overrideWithValue(
            const SupabaseConfig(
              url: 'https://example.supabase.co',
              publishableKey: 'sb_publishable_test',
            ),
          ),
          supabaseClientProvider.overrideWithValue(client),
          supabaseStartupErrorProvider.overrideWithValue(null),
        ],
        child: MaterialApp.router(
          theme: NorveTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin Dashboard'), findsOneWidget);
    expect(find.text('ADMINISTRATION'), findsOneWidget);
  });

  testWidgets(
    'visiting /admin/sign-in automatically redirects an authorized administrator to /admin',
    (tester) async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final router = createAdminWebRouter(initialLocation: '/admin/sign-in');
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            applicationRoleProvider.overrideWithValue(
              const AsyncData(ApplicationRole.administrator),
            ),
            supabaseConfigProvider.overrideWithValue(
              const SupabaseConfig(
                url: 'https://example.supabase.co',
                publishableKey: 'sb_publishable_test',
              ),
            ),
            supabaseClientProvider.overrideWithValue(client),
            supabaseStartupErrorProvider.overrideWithValue(null),
          ],
          child: MaterialApp.router(
            theme: NorveTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin Dashboard'), findsOneWidget);
      expect(find.text('ADMINISTRATION'), findsOneWidget);
      expect(find.text('Admin Sign In'), findsNothing);
      expect(find.text('Open Admin Dashboard'), findsNothing);
      expect(
        find.text(
          'Administrator access is verified by the database. There is no public admin registration.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'visiting /admin/sign-in displays clean sign-in form without technical description for unauthenticated user',
    (tester) async {
      final router = createAdminWebRouter(initialLocation: '/admin/sign-in');
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            applicationRoleProvider.overrideWithValue(
              const AsyncData(ApplicationRole.signedOut),
            ),
            supabaseConfigProvider.overrideWithValue(
              const SupabaseConfig(
                url: 'https://example.supabase.co',
                publishableKey: 'sb_publishable_test',
              ),
            ),
            supabaseClientProvider.overrideWithValue(
              SupabaseClient(
                'https://example.supabase.co',
                'sb_publishable_test',
                authOptions: const AuthClientOptions(autoRefreshToken: false),
              ),
            ),
            supabaseStartupErrorProvider.overrideWithValue(null),
          ],
          child: MaterialApp.router(
            theme: NorveTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin Sign In'), findsOneWidget);
      expect(
        find.text(
          'Administrator access is verified by the database. There is no public admin registration.',
        ),
        findsNothing,
      );
      expect(find.text('Open Admin Dashboard'), findsNothing);
      expect(find.byKey(const ValueKey('admin-email')), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-password')), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-sign-in-submit')), findsOneWidget);
      expect(find.text('Admin Dashboard'), findsNothing);
    },
  );

  testWidgets(
    'unauthorised customer on /admin/sign-in sees notice and cannot access dashboard',
    (tester) async {
      final router = createAdminWebRouter(initialLocation: '/admin/sign-in');
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            applicationRoleProvider.overrideWithValue(
              const AsyncData(ApplicationRole.customer),
            ),
            supabaseConfigProvider.overrideWithValue(
              const SupabaseConfig(
                url: 'https://example.supabase.co',
                publishableKey: 'sb_publishable_test',
              ),
            ),
            supabaseClientProvider.overrideWithValue(
              SupabaseClient(
                'https://example.supabase.co',
                'sb_publishable_test',
                authOptions: const AuthClientOptions(autoRefreshToken: false),
              ),
            ),
            supabaseStartupErrorProvider.overrideWithValue(null),
          ],
          child: MaterialApp.router(
            theme: NorveTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin Sign In'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('admin-unauthorized-session')),
        findsOneWidget,
      );
      expect(find.text('Admin Dashboard'), findsNothing);
      expect(find.text('Open Admin Dashboard'), findsNothing);
    },
  );
}
