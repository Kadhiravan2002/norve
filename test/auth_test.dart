import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/app/norve_app.dart';
import 'package:norve/core/auth/auth_providers.dart';
import 'package:norve/core/auth/auth_repository.dart';
import 'package:norve/core/supabase/supabase_config.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({AuthSession? initialSession})
    : _session = initialSession;

  AuthSession? _session;
  final _events = StreamController<AuthSession?>.broadcast();
  final _authEvents = StreamController<AuthChangeEvent?>.broadcast();
  bool signedUp = false;
  bool signedIn = false;
  bool failSignIn = false;
  bool signUpWithoutSession = false;
  Object? signUpError;
  bool signedOut = false;
  bool resetRequested = false;
  bool passwordUpdated = false;

  @override
  AuthSession? get currentSession => _session;

  @override
  Stream<AuthSession?> watchSession() async* {
    yield _session;
    yield* _events.stream;
  }

  @override
  Stream<AuthChangeEvent?> watchAuthEvents() => _authEvents.stream;

  void _setSession(AuthSession? value) {
    _session = value;
    _events.add(value);
  }

  @override
  Future<AuthActionResult> signUp({
    required String email,
    required String password,
  }) async {
    signedUp = true;
    if (signUpError != null) throw signUpError!;
    if (signUpWithoutSession) {
      return const AuthActionResult(emailConfirmationRequired: true);
    }
    final session = AuthSession(userId: 'new-customer', email: email);
    _setSession(session);
    return AuthActionResult(session: session);
  }

  @override
  Future<AuthActionResult> signIn({
    required String email,
    required String password,
  }) async {
    signedIn = true;
    if (failSignIn) throw AuthException('Invalid login credentials.');
    final session = AuthSession(userId: 'customer-user', email: email);
    _setSession(session);
    return AuthActionResult(session: session);
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    _setSession(null);
  }

  @override
  Future<void> sendPasswordReset(String email, {String? redirectTo}) async {
    resetRequested = true;
  }

  @override
  Future<void> updatePassword(String password) async {
    passwordUpdated = true;
  }

  void dispose() {
    unawaited(_events.close());
    unawaited(_authEvents.close());
  }
}

void main() {
  accountOverrides(AuthRepository repository) => [
    supabaseConfigProvider.overrideWithValue(
      const SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'sb_publishable_test',
      ),
    ),
    authRepositoryProvider.overrideWithValue(repository),
    authServicesAvailableProvider.overrideWithValue(true),
  ];

  testWidgets('customer sign-up with a session navigates to Home', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: accountOverrides(repository),
        child: const NorveApp(initialLocation: '/account'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Account').first);
    await tester.enterText(
      find.byKey(const ValueKey('customer-email')),
      'new@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customer-password')),
      'password123',
    );
    await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
    await tester.pumpAndSettle();
    expect(repository.signedUp, isTrue);
    expect(find.text('A New Perspective on Everyday Style'), findsOneWidget);
    expect(repository.currentSession?.userId, 'new-customer');
    expect(find.textContaining('confirm your email'), findsNothing);
  });

  testWidgets('customer sign-up does not claim success without a session', (
    tester,
  ) async {
    final repository = _FakeAuthRepository()..signUpWithoutSession = true;
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: accountOverrides(repository),
        child: const NorveApp(initialLocation: '/account'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Account').first);
    await tester.enterText(
      find.byKey(const ValueKey('customer-email')),
      'new@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customer-password')),
      'password123',
    );
    await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
    await tester.pumpAndSettle();

    expect(repository.currentSession, isNull);
    expect(find.byKey(const ValueKey('customer-auth-error')), findsOneWidget);
    expect(find.textContaining('confirm your email'), findsNothing);
    expect(find.text('A New Perspective on Everyday Style'), findsNothing);
  });

  testWidgets('customer sign-up shows duplicate email errors from Supabase', (
    tester,
  ) async {
    final repository = _FakeAuthRepository()
      ..signUpError = AuthException('User already registered');
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: accountOverrides(repository),
        child: const NorveApp(initialLocation: '/account'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Account').first);
    await tester.enterText(
      find.byKey(const ValueKey('customer-email')),
      'existing@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customer-password')),
      'password123',
    );
    await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('User already registered'), findsOneWidget);
    expect(find.text('A New Perspective on Everyday Style'), findsNothing);
  });

  testWidgets('customer sign-up shows Supabase password policy errors', (
    tester,
  ) async {
    final repository = _FakeAuthRepository()
      ..signUpError = AuthException('Password does not meet the requirements');
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: accountOverrides(repository),
        child: const NorveApp(initialLocation: '/account'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Account').first);
    await tester.enterText(
      find.byKey(const ValueKey('customer-email')),
      'new@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customer-password')),
      'password123',
    );
    await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('Password does not meet the requirements'),
      findsOneWidget,
    );
    expect(find.text('A New Perspective on Everyday Style'), findsNothing);
  });

  testWidgets('customer sign-in updates the restored account session', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: accountOverrides(repository),
        child: const NorveApp(initialLocation: '/account'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('customer-email')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customer-password')),
      'password123',
    );
    await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
    await tester.pumpAndSettle();
    expect(repository.signedIn, isTrue);
    expect(repository.currentSession?.email, 'person@example.com');
    expect(find.text('A New Perspective on Everyday Style'), findsOneWidget);
  });

  testWidgets(
    'customer sign-in validates fields and reports authentication errors',
    (tester) async {
      final repository = _FakeAuthRepository()..failSignIn = true;
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: accountOverrides(repository),
          child: const NorveApp(initialLocation: '/account'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
      await tester.pumpAndSettle();
      expect(repository.signedIn, isFalse);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('customer-email')),
        'person@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('customer-password')),
        'password123',
      );
      final submit = find.byKey(const ValueKey('customer-auth-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(repository.signedIn, isTrue);
      expect(find.text('Invalid login credentials.'), findsOneWidget);
    },
  );

  testWidgets('restored customer session lands on Home', (tester) async {
    final repository = _FakeAuthRepository(
      initialSession: const AuthSession(
        userId: 'restored',
        email: 'returning@example.com',
      ),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: accountOverrides(repository),
        child: const NorveApp(initialLocation: '/account'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A New Perspective on Everyday Style'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    expect(find.byKey(const ValueKey('customer-auth-submit')), findsNothing);
    expect(find.text('Admin Sign In'), findsNothing);
    for (final destination in ['Home', 'Shop', 'Wishlist', 'Bag']) {
      expect(find.text(destination), findsOneWidget);
    }
    expect(find.text('NORVÉ'), findsOneWidget);
  });

  testWidgets('signed-out app startup opens Account sign-in', (tester) async {
    final repository = _FakeAuthRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: accountOverrides(repository),
        child: const NorveApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('customer-auth-submit')), findsOneWidget);
    expect(find.text('A New Perspective on Everyday Style'), findsNothing);
  });

  testWidgets('customer can request password reset through Supabase Auth', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: accountOverrides(repository),
        child: const NorveApp(initialLocation: '/account'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('customer-email')),
      'person@example.com',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('customer-password-reset')),
    );
    await tester.tap(find.byKey(const ValueKey('customer-password-reset')));
    await tester.pumpAndSettle();
    expect(repository.resetRequested, isTrue);
    expect(
      find.text(
        'If this email is registered, a password reset link has been sent.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('password recovery opens the password update form', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: accountOverrides(repository),
        child: const NorveApp(initialLocation: '/account'),
      ),
    );
    await tester.pumpAndSettle();
    repository._authEvents.add(AuthChangeEvent.passwordRecovery);
    await tester.pumpAndSettle();
    expect(find.text('Choose a new password'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      'newpassword123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirm-new-password')),
      'newpassword123',
    );
    await tester.tap(find.byKey(const ValueKey('save-new-password')));
    await tester.pumpAndSettle();
    expect(repository.passwordUpdated, isTrue);
    expect(find.text('Account'), findsNWidgets(2));
  });

  testWidgets(
    'customer sign-out clears the session and protected admin route redirects',
    (tester) async {
      final repository = _FakeAuthRepository(
        initialSession: const AuthSession(
          userId: 'customer-only',
          email: 'customer@example.com',
        ),
      );
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [...accountOverrides(repository)],
          child: const NorveApp(initialLocation: '/admin/products'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('customer@example.com'), findsOneWidget);
      expect(find.text('Products'), findsNothing);
      expect(find.text('Admin Dashboard'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('customer-sign-out')));
      await tester.pumpAndSettle();
      expect(repository.signedOut, isTrue);
      expect(
        find.byKey(const ValueKey('customer-auth-submit')),
        findsOneWidget,
      );
      expect(find.text('Admin Dashboard'), findsNothing);
    },
  );
}
