import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/auth/application_role_provider.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/admin/admin_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthClient extends GoTrueClient {
  _FakeAuthClient({required this.fakeUser});
  final User? fakeUser;

  @override
  User? get currentUser => fakeUser;
}

class _FakeSupabaseClient extends SupabaseClient {
  _FakeSupabaseClient({required this.fakeAuth})
      : super(
          'https://example.supabase.co',
          'sb_publishable_test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
  final GoTrueClient fakeAuth;

  @override
  GoTrueClient get auth => fakeAuth;
}

void main() {
  const testUser = User(
    id: 'user-123',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
    email: 'kadhiravan2026@gmail.com',
  );

  final clientWithEmail = _FakeSupabaseClient(
    fakeAuth: _FakeAuthClient(fakeUser: testUser),
  );

  Widget buildAdminApp({
    required SupabaseClient client,
    required Widget child,
  }) {
    final router = GoRouter(
      initialLocation: '/admin/categories',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AdminShell(child: child),
          routes: [
            GoRoute(
              path: '/admin/categories',
              builder: (context, state) => child,
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        applicationRoleProvider.overrideWithValue(
          const AsyncData(ApplicationRole.administrator),
        ),
        supabaseClientProvider.overrideWithValue(client),
      ],
      child: MaterialApp.router(
        theme: NorveTheme.light,
        routerConfig: router,
      ),
    );
  }

  testWidgets(
      'AdminShell mobile header renders without overflow at 425px and 390px with long email identity',
      (tester) async {
    // 1. Test at 425px mobile width
    tester.view.physicalSize = const Size(425, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      buildAdminApp(
        client: clientWithEmail,
        child: const Scaffold(body: Text('Categories Screen Content')),
      ),
    );
    await tester.pumpAndSettle();

    // Confirm no RenderFlex overflow
    expect(tester.takeException(), isNull);

    // NORVÉ brand wordmark is visible
    expect(find.text('NORVÉ'), findsOneWidget);

    // At 425px, space permits ADMINISTRATION badge
    expect(find.text('ADMINISTRATION'), findsOneWidget);

    // Email identity badge is present and accessible via tooltip
    expect(find.byTooltip('kadhiravan2026@gmail.com'), findsOneWidget);
    expect(find.text('kadhiravan2026@gmail.com'), findsOneWidget);

    // Sign out button is visible and usable
    expect(find.byTooltip('Sign Out'), findsOneWidget);

    // 2. Test at 390px mobile width
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      buildAdminApp(
        client: clientWithEmail,
        child: const Scaffold(body: Text('Categories Screen Content')),
      ),
    );
    await tester.pumpAndSettle();

    // Confirm no RenderFlex overflow
    expect(tester.takeException(), isNull);

    // NORVÉ brand wordmark remains visible
    expect(find.text('NORVÉ'), findsOneWidget);

    // At 390px, ADMINISTRATION badge is cleanly omitted where space does not permit
    expect(find.text('ADMINISTRATION'), findsNothing);

    // Email identity badge is present and accessible via tooltip
    expect(find.byTooltip('kadhiravan2026@gmail.com'), findsOneWidget);
    expect(find.text('kadhiravan2026@gmail.com'), findsOneWidget);

    // Sign out button remains visible and usable
    expect(find.byTooltip('Sign Out'), findsOneWidget);
  });

  testWidgets(
      'AdminShell desktop header and sidebar remain intact at 1280px',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      buildAdminApp(
        client: clientWithEmail,
        child: const Scaffold(body: Text('Categories Screen Content')),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('NORVÉ'), findsOneWidget);
    expect(find.text('ADMINISTRATION'), findsOneWidget);
    expect(find.text('MANAGEMENT'), findsOneWidget);
    expect(find.byTooltip('kadhiravan2026@gmail.com'), findsOneWidget);
    expect(find.byTooltip('Sign Out'), findsOneWidget);
  });
}
