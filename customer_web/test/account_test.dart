import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/core/auth/auth_repository.dart';
import 'package:norve/features/account/customer_data_providers.dart';
import 'package:norve/features/orders/order_providers.dart';
import 'package:norve_customer_web/app/password_recovery.dart';
import 'package:norve_customer_web/pages/auth_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

late ProviderContainer container;

/// Waits out a route transition, during which the old page is still present.
Future<void> finishTransition(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 1));

Future<FakeAuthRepository> pumpAccount(
  WidgetTester tester, {
  required String location,
  FakeAuthRepository? auth,
  Size size = const Size(1280, 1400),
}) async {
  final repository = auth ?? FakeAuthRepository();
  container = await pumpStorefront(
    tester,
    catalogue: () async => [testProduct()],
    location: location,
    size: size,
    auth: repository,
    overrides: [
      customerDataRepositoryProvider.overrideWithValue(FakeCustomerData()),
      customerOrdersProvider.overrideWith((ref) async => const []),
      customerOrderProvider.overrideWith(
        (ref, id) async => throw Exception('not found'),
      ),
    ],
  );
  await settle(tester);
  return repository;
}

Future<void> enterCredentials(
  WidgetTester tester, {
  String email = 'customer@example.test',
  String password = 'correct-horse',
}) async {
  await tester.enterText(find.byKey(const ValueKey('auth-email')), email);
  await tester.enterText(find.byKey(const ValueKey('auth-password')), password);
}

Future<void> submit(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('auth-submit')));
  await settle(tester);
}

String passwordFieldText(WidgetTester tester) => tester
    .widget<TextFormField>(find.byKey(const ValueKey('auth-password')))
    .controller!
    .text;

void main() {
  group('sign in', () {
    testWidgets('returns to the page the customer came from', (tester) async {
      final auth = await pumpAccount(tester, location: '/checkout');
      expect(find.text('Sign in to your account'), findsOneWidget);

      await enterCredentials(tester);
      await submit(tester);

      await finishTransition(tester);

      expect(auth.signInCalls, 1);
      expect(currentUri(container).path, '/checkout');
      expect(find.text('Sign in to your account'), findsNothing);
    });

    testWidgets('opens the account page when there is no destination', (
      tester,
    ) async {
      await pumpAccount(tester, location: '/account');
      await enterCredentials(tester);
      await submit(tester);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Asha Rao'), findsOneWidget);
    });

    testWidgets('explains wrong details and clears the password', (
      tester,
    ) async {
      final auth = FakeAuthRepository(
        onSignIn: () async => throw const AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      );
      await pumpAccount(tester, location: '/login', auth: auth);
      await enterCredentials(tester);
      await submit(tester);

      expect(
        find.text('That email or password is not correct.'),
        findsOneWidget,
      );
      expect(passwordFieldText(tester), isEmpty);
    });

    testWidgets('validates before contacting the server', (tester) async {
      final auth = await pumpAccount(tester, location: '/login');
      await enterCredentials(tester, email: 'not-an-email', password: 'short');
      await submit(tester);

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(auth.signInCalls, 0);
    });
  });

  group('registration', () {
    testWidgets('signs in straight away when confirmation is off', (
      tester,
    ) async {
      await pumpAccount(tester, location: '/register');
      expect(find.text('Create your account'), findsOneWidget);
      await enterCredentials(tester);
      await submit(tester);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('asks the customer to check email when confirmation is on', (
      tester,
    ) async {
      final auth = FakeAuthRepository(
        onSignUp: () async =>
            const AuthActionResult(emailConfirmationRequired: true),
      );
      await pumpAccount(tester, location: '/register', auth: auth);
      await enterCredentials(tester);
      await submit(tester);

      expect(
        find.text('Check your email to confirm your account, then sign in.'),
        findsOneWidget,
      );
      expect(find.text('Create your account'), findsOneWidget);
    });

    testWidgets('switching between forms keeps the return destination', (
      tester,
    ) async {
      await pumpAccount(tester, location: '/checkout');
      await tester.tap(find.byKey(const ValueKey('auth-switch-mode')));
      await settle(tester);
      await finishTransition(tester);
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Sign in to your account'), findsNothing);
      expect(currentUri(container).path, '/register');
      expect(currentUri(container).queryParameters['from'], '/checkout');

      await enterCredentials(tester);
      await submit(tester);
      await finishTransition(tester);
      expect(currentUri(container).path, '/checkout');
    });
  });

  group('forgotten password', () {
    testWidgets('asks for the email first', (tester) async {
      final auth = await pumpAccount(tester, location: '/login');
      await tester.tap(find.byKey(const ValueKey('auth-forgot-password')));
      await settle(tester);
      expect(
        find.text('Enter your email address above first.'),
        findsOneWidget,
      );
      expect(auth.resetEmail, isNull);
    });

    testWidgets('asks for a link back to this website', (tester) async {
      final auth = await pumpAccount(tester, location: '/login');
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        'customer@example.test',
      );
      await tester.tap(find.byKey(const ValueKey('auth-forgot-password')));
      await settle(tester);

      expect(auth.resetEmail, 'customer@example.test');
      expect(auth.resetRedirect, 'https://norve.test/account/reset-password');
      expect(find.byKey(const ValueKey('auth-message')), findsOneWidget);
    });

    testWidgets('a link with no session offers a new one', (tester) async {
      await pumpAccount(tester, location: '/account/reset-password?code=spent');
      expect(
        find.byKey(const ValueKey('password-reset-link-invalid')),
        findsOneWidget,
      );
      await tester.tap(find.text('Go to Sign In'));
      await settle(tester);
      expect(find.text('Sign in to your account'), findsOneWidget);
    });

    testWidgets('a working link shows the new password form', (tester) async {
      await pumpAccount(
        tester,
        location: '/account/reset-password',
        auth: FakeAuthRepository(session: FakeAuthRepository.customer),
      );
      expect(find.text('Choose a new password'), findsOneWidget);
    });

    test('only the reset page treats a URL as a reset link', () {
      for (final url in [
        '/account/reset-password?code=abc',
        '/account/reset-password?error=access_denied',
        '/account/reset-password#error_code=otp_expired',
      ]) {
        expect(isPasswordRecoveryLink(Uri.parse(url)), isTrue, reason: url);
      }
      for (final url in ['/account/reset-password', '/shop?code=abc']) {
        expect(isPasswordRecoveryLink(Uri.parse(url)), isFalse, reason: url);
      }
    });

    test('a failed link does not stop the site from starting', () async {
      final client = GoTrueClient(url: 'https://example.supabase.co/auth/v1');
      addTearDown(client.dispose);
      await completePasswordRecoveryLink(
        client,
        Uri.parse(
          'https://norve.test/account/reset-password'
          '?error=access_denied&error_description=Link+expired',
        ),
      );
      expect(client.currentSession, isNull);
    });
  });

  group('account page', () {
    testWidgets('shows the customer details and signs out to sign-in', (
      tester,
    ) async {
      final auth = FakeAuthRepository(session: FakeAuthRepository.customer);
      await pumpAccount(tester, location: '/account', auth: auth);

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Personal details'), findsOneWidget);
      expect(find.text('Saved addresses'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('account-sign-out')));
      await settle(tester);
      expect(auth.session, isNull);
      expect(find.text('Sign in to your account'), findsOneWidget);
      expect(find.text('Asha Rao'), findsNothing);
    });

    testWidgets('Your Orders opens the order list, with a way back', (
      tester,
    ) async {
      await pumpAccount(
        tester,
        location: '/account',
        auth: FakeAuthRepository(session: FakeAuthRepository.customer),
      );
      await tester.tap(find.byKey(const ValueKey('account-orders')));
      await settle(tester);
      expect(
        find.text(
          'Your order history will appear here after your first order.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('back-link')));
      await settle(tester);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('an order that cannot load still has a way back', (
      tester,
    ) async {
      await pumpAccount(
        tester,
        location: '/account/orders/other-customers-order',
        auth: FakeAuthRepository(session: FakeAuthRepository.customer),
      );
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('back-link')));
      await settle(tester);
      expect(currentUri(container).path, '/account/orders');
      expect(
        find.text(
          'Your order history will appear here after your first order.',
        ),
        findsOneWidget,
      );
    });

    for (final width in [360.0, 768.0, 1440.0]) {
      testWidgets('fits at ${width.toInt()}px', (tester) async {
        await pumpAccount(tester, location: '/login', size: Size(width, 1000));
        expect(tester.takeException(), isNull);
        await pumpAccount(
          tester,
          location: '/account',
          size: Size(width, 1000),
          auth: FakeAuthRepository(session: FakeAuthRepository.customer),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('error wording', () {
    test('never shows raw server failures', () {
      expect(
        authErrorMessage(
          const AuthApiException('upstream timeout', statusCode: '504'),
        ),
        contains('Check your connection'),
      );
      expect(
        authErrorMessage(Exception('boom')),
        contains('Check your connection'),
      );
    });

    test('points an existing customer to sign-in', () {
      expect(
        authErrorMessage(
          const AuthApiException(
            'User already registered',
            statusCode: '422',
            code: 'user_already_exists',
          ),
        ),
        contains('Sign in instead'),
      );
    });
  });
}
