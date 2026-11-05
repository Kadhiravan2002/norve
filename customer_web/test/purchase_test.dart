import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/features/account/customer_data_providers.dart';
import 'package:norve/features/bag/bag_provider.dart';
import 'package:norve/features/orders/order_providers.dart';
import 'package:norve/features/orders/order_repository.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve/features/wishlist/wishlist_provider.dart';
import 'package:norve_customer_web/orders/interrupted_order.dart';
import 'package:norve_customer_web/orders/storefront_order_repository.dart';
import 'package:norve_customer_web/wishlist/storefront_wishlist.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'support/harness.dart';

class FakeOrders extends OrderRepository {
  FakeOrders({this.onQuote, this.onPlace, this.orders = const []});

  Future<CheckoutQuote> Function()? onQuote;
  Future<OrderConfirmation> Function()? onPlace;
  List<OrderRecord> orders;
  int placeCalls = 0;
  DeliveryDetails? delivery;

  @override
  Future<CheckoutQuote> createQuote(List<BagItem> items) =>
      (onQuote ?? () async => testQuote())();

  @override
  Future<OrderConfirmation> placeCodOrder(
    String quoteId,
    DeliveryDetails delivery,
  ) {
    placeCalls++;
    this.delivery = delivery;
    return (onPlace ?? () async => testConfirmation())();
  }

  @override
  Future<List<OrderRecord>> customerOrders() async => orders;
}

CheckoutQuote testQuote({int total = 2598}) => CheckoutQuote(
  id: 'quote-1',
  items: const [
    QuoteItem(
      productId: testProductId,
      variantId: 'v1',
      productName: 'Live Linen Shirt',
      imageUrl: '',
      size: 'M',
      color: 'Black',
      quantity: 1,
      unitPrice: 2499,
      lineTotal: 2499,
    ),
  ],
  subtotal: 2499,
  shipping: 99,
  tax: 0,
  total: total,
  expiresAt: DateTime.now().add(const Duration(minutes: 10)),
);

OrderConfirmation testConfirmation() => OrderConfirmation(
  id: 'order-1',
  reference: 'NRV-1001',
  subtotal: 2499,
  shipping: 99,
  tax: 0,
  total: 2598,
  status: 'pending',
  paymentStatus: 'pending',
  createdAt: DateTime.now(),
);

OrderRecord testOrder({required DateTime createdAt, int total = 2598}) =>
    OrderRecord(
      id: 'order-1',
      reference: 'NRV-1001',
      email: 'customer@example.test',
      customerName: 'Asha Rao',
      phone: '+91 98765 43210',
      addressLine1: '12 Lake Road',
      addressLine2: '',
      city: 'Chennai',
      region: 'Tamil Nadu',
      postalCode: '600001',
      subtotal: 2499,
      shipping: 99,
      tax: 0,
      total: total,
      status: 'pending',
      paymentStatus: 'pending',
      createdAt: createdAt,
      items: const [],
    );

Future<SharedPreferences> freshPreferences([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

late ProviderContainer container;

Future<void> pumpShop(
  WidgetTester tester, {
  required String location,
  required SharedPreferences preferences,
  FakeAuthRepository? auth,
  FakeOrders? orders,
  Future<List<Product>> Function()? catalogue,
  Size size = const Size(1280, 2400),
  List<Override> overrides = const [],
}) async {
  final fakeOrders = orders ?? FakeOrders();
  container = await pumpStorefront(
    tester,
    catalogue: catalogue ?? () async => [testProduct()],
    location: location,
    size: size,
    auth: auth ?? FakeAuthRepository(),
    overrides: [
      bagPreferencesProvider.overrideWithValue(preferences),
      customerDataRepositoryProvider.overrideWithValue(FakeCustomerData()),
      orderRepositoryProvider.overrideWith(
        (ref) => StorefrontOrderRepository(
          fakeOrders,
          ref.watch(interruptedOrderStoreProvider),
        ),
      ),
      ...overrides,
    ],
  );
  await settle(tester);
}

void addToBag({int stockLimit = 5, String productId = testProductId}) =>
    container
        .read(bagProvider.notifier)
        .add(
          testProduct(id: productId),
          size: 'M',
          color: 'Black',
          stockLimit: stockLimit,
        );

Future<void> fillDeliveryForm(WidgetTester tester) async {
  const fields = {
    'Full name': 'Asha Rao',
    'Phone number': '+91 98765 43210',
    'House / Flat / Building': '12 Lake Road',
    'Street / Area': 'Adyar',
    'City': 'Chennai',
    'State': 'Tamil Nadu',
    'Postal / PIN code': '600001',
  };
  for (final entry in fields.entries) {
    await tester.enterText(
      find.widgetWithText(TextFormField, entry.key),
      entry.value,
    );
  }
}

Future<void> reachReview(WidgetTester tester) async {
  await fillDeliveryForm(tester);
  await tester.tap(find.byKey(const ValueKey('review-order')));
  await settle(tester);
}

void main() {
  const signedIn = FakeAuthRepository.customer;

  group('wishlist in the browser', () {
    testWidgets('a guest wishlist survives a reload', (tester) async {
      final preferences = await freshPreferences();
      await pumpShop(tester, location: '/shop', preferences: preferences);
      container.read(wishlistProvider.notifier).toggle(testProductId);
      expect(preferences.getStringList(wishlistGuestKey), [testProductId]);

      await pumpShop(tester, location: '/shop', preferences: preferences);
      expect(container.read(wishlistProvider), {testProductId});
    });

    testWidgets('guest pieces join the account at sign-in', (tester) async {
      final preferences = await freshPreferences({
        wishlistUserKey(signedIn.userId): ['saved-before'],
      });
      final auth = FakeAuthRepository();
      await pumpShop(
        tester,
        location: '/shop',
        preferences: preferences,
        auth: auth,
      );
      container.read(wishlistProvider.notifier).toggle(testProductId);

      auth.setSession(signedIn);
      await settle(tester);

      expect(container.read(wishlistProvider), {'saved-before', testProductId});
      expect(preferences.getStringList(wishlistGuestKey), isNull);
    });

    testWidgets('sign-out hides the list and sign-in restores it', (
      tester,
    ) async {
      final preferences = await freshPreferences();
      final auth = FakeAuthRepository(session: signedIn);
      await pumpShop(
        tester,
        location: '/shop',
        preferences: preferences,
        auth: auth,
      );
      container.read(wishlistProvider.notifier).toggle(testProductId);

      auth.setSession(null);
      await settle(tester);
      expect(container.read(wishlistProvider), isEmpty);

      auth.setSession(signedIn);
      await settle(tester);
      expect(container.read(wishlistProvider), {testProductId});
    });

    testWidgets('one customer never sees another customer\'s list', (
      tester,
    ) async {
      final preferences = await freshPreferences({
        wishlistUserKey('someone-else'): ['their-piece'],
      });
      await pumpShop(
        tester,
        location: '/shop',
        preferences: preferences,
        auth: FakeAuthRepository(session: signedIn),
      );
      expect(container.read(wishlistProvider), isEmpty);
    });
  });

  group('wishlist page', () {
    testWidgets('shows saved pieces and hides unavailable ones', (
      tester,
    ) async {
      final preferences = await freshPreferences({
        wishlistGuestKey: [testProductId, 'removed-from-store'],
      });
      await pumpShop(tester, location: '/wishlist', preferences: preferences);
      expect(find.text('Live Linen Shirt'), findsOneWidget);
      expect(find.text('1 piece saved'), findsOneWidget);
    });

    testWidgets('an empty wishlist offers a way to keep shopping', (
      tester,
    ) async {
      await pumpShop(
        tester,
        location: '/wishlist',
        preferences: await freshPreferences(),
      );
      expect(find.byKey(const ValueKey('wishlist-empty')), findsOneWidget);
      expect(find.text('Continue Shopping'), findsOneWidget);
    });

    testWidgets('does not claim to be empty while pieces are loading', (
      tester,
    ) async {
      final completer = Completer<List<Product>>();
      final preferences = await freshPreferences({
        wishlistGuestKey: [testProductId],
      });
      await pumpShop(
        tester,
        location: '/wishlist',
        preferences: preferences,
        catalogue: () => completer.future,
      );
      expect(find.byKey(const ValueKey('wishlist-empty')), findsNothing);
      expect(find.byKey(const ValueKey('catalogue-loading')), findsOneWidget);

      completer.complete([testProduct()]);
      await settle(tester);
      expect(find.text('Live Linen Shirt'), findsOneWidget);
    });
  });

  group('bag page', () {
    testWidgets('shows lines, totals and an empty state', (tester) async {
      await pumpShop(
        tester,
        location: '/bag',
        preferences: await freshPreferences(),
      );
      expect(find.byKey(const ValueKey('bag-empty')), findsOneWidget);

      addToBag();
      await settle(tester);
      expect(find.text('Live Linen Shirt'), findsOneWidget);
      expect(find.text('1 item'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('bag-subtotal'))).data,
        formatInr(2499),
      );

      await tester.tap(find.byTooltip('Remove Live Linen Shirt'));
      await settle(tester);
      expect(find.byKey(const ValueKey('bag-empty')), findsOneWidget);
    });

    testWidgets('does not call a product unavailable while loading', (
      tester,
    ) async {
      final completer = Completer<List<Product>>();
      await pumpShop(
        tester,
        location: '/bag',
        preferences: await freshPreferences(),
        catalogue: () => completer.future,
      );
      addToBag();
      await settle(tester);
      expect(find.text('Unavailable product'), findsNothing);
      expect(find.text('Loading…'), findsOneWidget);

      completer.complete(const []);
      await settle(tester);
      expect(find.text('Unavailable product'), findsOneWidget);
    });

    testWidgets('the increase button stops at the stock limit', (tester) async {
      await pumpShop(
        tester,
        location: '/bag',
        preferences: await freshPreferences(),
      );
      addToBag(stockLimit: 2);
      await settle(tester);

      await tester.tap(find.byTooltip('Increase quantity'));
      await settle(tester);

      final increase = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add),
      );
      expect(increase.onPressed, isNull);
      expect(find.text('Only 2 available'), findsOneWidget);
      expect(container.read(bagItemCountProvider), 2);
    });

    testWidgets('a guest goes to sign-in, then back to checkout', (
      tester,
    ) async {
      await pumpShop(
        tester,
        location: '/bag',
        preferences: await freshPreferences(),
      );
      addToBag();
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('proceed-to-checkout')));
      await settle(tester);

      final uri = currentUri(container);
      expect(uri.path, '/login');
      expect(uri.queryParameters['from'], '/checkout');
      expect(container.read(bagItemCountProvider), 1);
    });

    for (final width in [360.0, 768.0, 1440.0]) {
      testWidgets('fits at ${width.toInt()}px', (tester) async {
        await pumpShop(
          tester,
          location: '/bag',
          preferences: await freshPreferences(),
          size: Size(width, 1000),
        );
        addToBag();
        await settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('checkout', () {
    testWidgets('places a COD order and empties the bag', (tester) async {
      final orders = FakeOrders();
      final preferences = await freshPreferences();
      await pumpShop(
        tester,
        location: '/checkout',
        preferences: preferences,
        auth: FakeAuthRepository(session: signedIn),
        orders: orders,
      );
      addToBag();
      await settle(tester);

      await reachReview(tester);
      expect(find.text('Final order summary'), findsOneWidget);
      expect(find.text(formatInr(2598)), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('confirm-cod-order')));
      await settle(tester);

      expect(orders.placeCalls, 1);
      expect(orders.delivery?.customerName, 'Asha Rao');
      expect(find.text('Your order is confirmed'), findsOneWidget);
      expect(find.text('Reference NRV-1001'), findsOneWidget);
      expect(container.read(bagProvider), isEmpty);
      expect(preferences.getString(interruptedOrderKey), isNull);
    });

    testWidgets('a wide screen has a way back to the bag', (tester) async {
      await pumpShop(
        tester,
        location: '/checkout',
        preferences: await freshPreferences(),
        auth: FakeAuthRepository(session: signedIn),
      );
      addToBag();
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('checkout-back-to-bag')));
      await settle(tester);
      expect(currentUri(container).path, '/bag');
    });

    testWidgets('a stock failure at review is shown in plain words', (
      tester,
    ) async {
      await pumpShop(
        tester,
        location: '/checkout',
        preferences: await freshPreferences(),
        auth: FakeAuthRepository(session: signedIn),
        orders: FakeOrders(
          onQuote: () async => throw const PostgrestException(
            message: 'insufficient stock for Shirt (M / Black)',
            code: 'P0001',
          ),
        ),
      );
      addToBag();
      await settle(tester);
      await reachReview(tester);

      final error = tester.widget<Text>(
        find.byKey(const ValueKey('checkout-error')),
      );
      expect(error.data, contains('Lower its quantity'));
      expect(error.data, isNot(contains('PostgrestException')));
      expect(error.data, isNot(contains('P0001')));
    });

    testWidgets('a lost connection keeps the bag and allows a safe retry', (
      tester,
    ) async {
      var attempts = 0;
      final preferences = await freshPreferences();
      final orders = FakeOrders(
        onPlace: () async {
          attempts++;
          if (attempts == 1) throw Exception('network down');
          return testConfirmation();
        },
      );
      await pumpShop(
        tester,
        location: '/checkout',
        preferences: preferences,
        auth: FakeAuthRepository(session: signedIn),
        orders: orders,
      );
      addToBag();
      await settle(tester);
      await reachReview(tester);

      await tester.tap(find.byKey(const ValueKey('confirm-cod-order')));
      await settle(tester);
      expect(find.textContaining('will not create a second'), findsOneWidget);
      expect(container.read(bagProvider), hasLength(1));
      expect(preferences.getString(interruptedOrderKey), isNotNull);

      await tester.tap(find.byKey(const ValueKey('confirm-cod-order')));
      await settle(tester);
      expect(find.text('Your order is confirmed'), findsOneWidget);
      expect(preferences.getString(interruptedOrderKey), isNull);
    });
  });

  group('reload during order placement', () {
    testWidgets('finds the order, empties the bag and prevents a repeat', (
      tester,
    ) async {
      final preferences = await freshPreferences();
      await InterruptedOrderStore(preferences).mark(2598);
      await pumpShop(
        tester,
        location: '/bag',
        preferences: preferences,
        auth: FakeAuthRepository(session: signedIn),
        orders: FakeOrders(orders: [testOrder(createdAt: DateTime.now())]),
      );
      addToBag();
      await settle(tester);

      routerOf(container).go('/checkout');
      await settle(tester);

      expect(
        find.byKey(const ValueKey('checkout-order-recovered')),
        findsOneWidget,
      );
      expect(find.textContaining('NRV-1001'), findsOneWidget);
      expect(container.read(bagProvider), isEmpty);
      expect(preferences.getString(interruptedOrderKey), isNull);
    });

    testWidgets('continues normally when the order did not go through', (
      tester,
    ) async {
      final preferences = await freshPreferences();
      await InterruptedOrderStore(preferences).mark(2598);
      await pumpShop(
        tester,
        location: '/bag',
        preferences: preferences,
        auth: FakeAuthRepository(session: signedIn),
      );
      addToBag();
      await settle(tester);

      routerOf(container).go('/checkout');
      await settle(tester);

      expect(find.text('Delivery details'), findsOneWidget);
      expect(container.read(bagProvider), hasLength(1));
      expect(preferences.getString(interruptedOrderKey), isNull);
    });

    test('only matches an order with the same total and a nearby time', () {
      final placedAt = DateTime.utc(2026, 11, 5, 12);
      final mark = (total: 2598, placedAt: placedAt);
      expect(
        matchInterruptedOrder([testOrder(createdAt: placedAt)], mark),
        isNotNull,
      );
      expect(
        matchInterruptedOrder([
          testOrder(createdAt: placedAt, total: 999),
        ], mark),
        isNull,
      );
      expect(
        matchInterruptedOrder([
          testOrder(createdAt: placedAt.subtract(const Duration(days: 1))),
        ], mark),
        isNull,
      );
    });

    test('ignores a damaged marker', () async {
      final preferences = await freshPreferences({
        interruptedOrderKey: 'not json',
      });
      expect(InterruptedOrderStore(preferences).read(), isNull);
    });
  });

  group('checkout wording', () {
    const cases = {
      'checkout quote expired; review your order again': 'has expired',
      'checkout quote was not found': 'has expired',
      'product prices changed; review your order again': 'price has changed',
      'stock changed; review your order again': 'Stock has changed',
      'a selected variant is no longer available': 'no longer available',
      'a selected product or variant is unavailable': 'no longer available',
      'delivery or tax charges changed; review your order again':
          'charges have changed',
      'delivery address details are invalid': 'delivery details',
    };

    cases.forEach((server, expected) {
      test(server, () {
        expect(
          readableCheckoutError(PostgrestException(message: server)),
          contains(expected),
        );
      });
    });

    test('sign-in failures ask the customer to sign in again', () {
      expect(
        readableCheckoutError(
          const PostgrestException(message: 'anything', code: '42501'),
        ),
        contains('Sign in again'),
      );
    });

    test('an unknown failure never shows the server text', () {
      expect(
        readableCheckoutError(
          const PostgrestException(message: 'relation public.x missing'),
        ),
        isNot(contains('relation')),
      );
    });
  });
}
