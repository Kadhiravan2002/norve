import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/core/auth/application_role_provider.dart';
import 'package:norve/core/supabase/supabase_config.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/admin/admin_sign_in_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Widget buildTestWidget({
    Size surfaceSize = const Size(1280, 800),
    bool showBackButton = false,
  }) {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

    return ProviderScope(
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
        supabaseClientProvider.overrideWithValue(client),
        supabaseStartupErrorProvider.overrideWithValue(null),
      ],
      child: MaterialApp(
        theme: NorveTheme.light,
        home: AdminSignInScreen(
          showBackButton: showBackButton,
          customerReturnLocation: '/account',
        ),
      ),
    );
  }

  testWidgets('renders centered login card matching reference layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Brand and editorial header matching reference
    expect(find.text('NORVÉ'), findsOneWidget);
    expect(find.text('Management Console'), findsOneWidget);
    expect(
      find.text(
        'Access the store operations, catalogue, orders, and collections.',
      ),
      findsOneWidget,
    );

    // Form fields, icons, and placeholders
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.byIcon(Icons.mail_outline), findsOneWidget);

    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    // Action button
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-email')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-password')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-sign-in-submit')), findsOneWidget);
  });

  testWidgets('renders responsive mobile layout without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(390, 844)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('NORVÉ'), findsOneWidget);
    expect(find.text('Management Console'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-email')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-password')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-sign-in-submit')), findsOneWidget);
  });

  testWidgets('toggles password visibility with eye icon button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final passwordField = find.byKey(const ValueKey('admin-password'));
    expect(passwordField, findsOneWidget);

    TextField getTextField() => tester.widget<TextField>(
          find.descendant(
            of: passwordField,
            matching: find.byType(TextField),
          ),
        );

    // Initially obscured
    expect(getTextField().obscureText, isTrue);
    expect(find.byTooltip('Show password'), findsOneWidget);

    // Tap toggle
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();

    // Now revealed
    expect(getTextField().obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);

    // Tap toggle again
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pumpAndSettle();

    // Obscured again
    expect(getTextField().obscureText, isTrue);
    expect(find.byTooltip('Show password'), findsOneWidget);
  });

  testWidgets('validates required fields upon submission', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Submit with empty fields
    await tester.tap(find.byKey(const ValueKey('admin-sign-in-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('displays back button when showBackButton is enabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget(showBackButton: true));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back to account'), findsOneWidget);
  });
}
