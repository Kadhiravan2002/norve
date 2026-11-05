import 'package:flutter_test/flutter_test.dart';
import 'package:norve_customer_web/app/route_guards.dart';

String? redirect(String url, {bool signedIn = false, bool? admin = false}) =>
    storefrontRedirect(
      Uri.parse(url),
      signedIn: signedIn,
      isAdministrator: admin,
    );

void main() {
  group('guests', () {
    for (final path in [
      '/',
      '/shop',
      '/shop?categoryId=abc',
      '/product/abc',
      '/wishlist',
      '/bag',
      '/account',
      '/account/reset-password',
    ]) {
      test('can open $path', () => expect(redirect(path), isNull));
    }

    test('are sent to sign-in from checkout, keeping the destination', () {
      final target = Uri.parse(redirect('/checkout')!);
      expect(target.path, '/account');
      expect(target.queryParameters['from'], '/checkout');
    });

    test('are sent to sign-in from orders, keeping the full destination', () {
      final target = Uri.parse(redirect('/account/orders/abc?x=1')!);
      expect(target.path, '/account');
      expect(target.queryParameters['from'], '/account/orders/abc?x=1');
      expect(
        Uri.parse(redirect('/account/orders')!).queryParameters['from'],
        '/account/orders',
      );
    });
  });

  group('signed-in customers', () {
    test('stay on protected pages and deep links', () {
      for (final path in ['/checkout', '/account/orders/abc', '/product/abc']) {
        expect(redirect(path, signedIn: true), isNull);
      }
    });

    test('return to the page they came from after sign-in', () {
      expect(
        redirect('/account?from=%2Fcheckout', signedIn: true),
        '/checkout',
      );
    });

    test('stay on the account page when there is no destination', () {
      expect(redirect('/account', signedIn: true), isNull);
    });
  });

  group('return path safety', () {
    test('rejects anything that could leave the storefront', () {
      for (final value in [
        null,
        '',
        'https://evil.example',
        '//evil.example',
        r'/\evil.example',
        'javascript:alert(1)',
      ]) {
        expect(safeReturnPath(value), isNull, reason: '$value');
      }
    });

    test('an unsafe from value is ignored after sign-in', () {
      expect(
        redirect('/account?from=https%3A%2F%2Fevil.example', signedIn: true),
        isNull,
      );
      expect(
        redirect('/account?from=%2F%2Fevil.example', signedIn: true),
        isNull,
      );
    });

    test('accepts a same-site path', () {
      expect(safeReturnPath('/shop?categoryId=abc'), '/shop?categoryId=abc');
    });
  });

  group('administrators', () {
    test('are kept out of the store, matching mobile', () {
      for (final path in ['/', '/shop', '/product/abc', '/checkout']) {
        expect(
          redirect(path, signedIn: true, admin: true),
          '/administrator-access',
        );
      }
    });

    test('do not loop on the administrator notice', () {
      expect(
        redirect('/administrator-access', signedIn: true, admin: true),
        isNull,
      );
    });

    test('/admin paths go to the administrator notice for everyone', () {
      expect(redirect('/admin'), '/administrator-access');
      expect(redirect('/admin/products'), '/administrator-access');
    });

    test('an unresolved role does not block a signed-in customer', () {
      expect(redirect('/shop', signedIn: true, admin: null), isNull);
    });

    test('paths that only start with admin are not caught', () {
      expect(redirect('/administrator-notes'), isNull);
    });
  });
}
