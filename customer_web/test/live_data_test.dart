import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/features/bag/bag_provider.dart';
import 'package:norve/features/orders/order_providers.dart';
import 'package:norve/features/orders/order_repository.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve/features/wishlist/wishlist_provider.dart';
import 'package:norve_customer_web/app/data_refresher.dart';
import 'package:norve_customer_web/catalog/storefront_catalog_repository.dart';
import 'package:norve_customer_web/wishlist/storefront_wishlist.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';

class CountingCatalogRepository extends StorefrontCatalogRepository {
  CountingCatalogRepository(this.result) : super(null);

  Product? result;
  int calls = 0;

  @override
  Future<Product?> fetchById(String id) async {
    calls++;
    return result;
  }
}

/// Leaves the tab and comes back, as the browser reports it.
Future<void> returnToTab(WidgetTester tester) async {
  tester.binding
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
    ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await settle(tester);
}

OrderRecord order(String status) => OrderRecord(
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
  total: 2598,
  status: status,
  paymentStatus: 'pending',
  createdAt: DateTime(2026, 11, 5),
  items: const [],
);

void main() {
  // Each test starts as a page the customer is looking at.
  setUp(
    () => TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed),
  );

  group('catalogue on returning to the tab', () {
    late int fetches;
    late DateTime now;

    Future<ProviderContainer> pumpShopPage(WidgetTester tester) async {
      fetches = 0;
      now = DateTime(2026, 11, 5, 12);
      final container = await pumpStorefront(
        tester,
        catalogue: () async {
          fetches++;
          return [testProduct()];
        },
        location: '/shop',
        overrides: [storefrontClockProvider.overrideWithValue(() => now)],
      );
      await settle(tester);
      return container;
    }

    testWidgets('is not refetched within two minutes', (tester) async {
      await pumpShopPage(tester);
      expect(fetches, 1);
      now = now.add(const Duration(minutes: 1, seconds: 59));
      await returnToTab(tester);
      expect(fetches, 1);
    });

    testWidgets('is refetched after two minutes, keeping products visible', (
      tester,
    ) async {
      await pumpShopPage(tester);
      now = now.add(catalogueRefreshAge);
      await returnToTab(tester);
      expect(fetches, 2);
      expect(find.text('Live Linen Shirt'), findsOneWidget);
    });

    testWidgets('picks up an administrator price change', (tester) async {
      var price = 2499;
      now = DateTime(2026, 11, 5, 12);
      await pumpStorefront(
        tester,
        catalogue: () async => [testProduct(price: price)],
        location: '/shop',
        overrides: [storefrontClockProvider.overrideWithValue(() => now)],
      );
      await settle(tester);
      expect(find.text(formatInr(2499)), findsOneWidget);

      price = 1999;
      now = now.add(catalogueRefreshAge);
      await returnToTab(tester);
      expect(find.text(formatInr(1999)), findsOneWidget);
    });

    testWidgets('retries straight away after a failed load', (tester) async {
      fetches = 0;
      now = DateTime(2026, 11, 5, 12);
      await pumpStorefront(
        tester,
        catalogue: () async {
          fetches++;
          if (fetches == 1) throw Exception('offline');
          return [testProduct()];
        },
        location: '/shop',
        overrides: [storefrontClockProvider.overrideWithValue(() => now)],
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('catalogue-error')), findsOneWidget);

      await returnToTab(tester);
      expect(find.text('Live Linen Shirt'), findsOneWidget);
    });
  });

  group('product page on returning to the tab', () {
    final sized = testProduct(
      requiresSize: true,
      sizes: const ['S', 'M'],
      variants: [testVariant('S', ''), testVariant('M', '')],
    );

    testWidgets('shows new stock without a spinner or a lost selection', (
      tester,
    ) async {
      final repository = CountingCatalogRepository(sized);
      await pumpStorefront(
        tester,
        catalogue: () async => [sized],
        location: '/product/$testProductId',
        catalogRepository: repository,
      );
      await settle(tester);
      final calls = repository.calls;

      await tester.tap(find.text('M'));
      await settle(tester);
      final selected = tester.widget<Text>(find.text('M')).style?.color;

      repository.result = testProduct(
        requiresSize: true,
        sizes: const ['S', 'M'],
        variants: [testVariant('S', '', stock: 0), testVariant('M', '')],
      );
      await returnToTab(tester);

      expect(repository.calls, calls + 1);
      expect(find.byKey(const ValueKey('catalogue-loading')), findsNothing);
      expect(find.text('Live Linen Shirt'), findsWidgets);
      expect(tester.widget<Text>(find.text('M')).style?.color, selected);
    });

    testWidgets('a product removed meanwhile becomes unavailable', (
      tester,
    ) async {
      final repository = CountingCatalogRepository(sized);
      await pumpStorefront(
        tester,
        catalogue: () async => [sized],
        location: '/product/$testProductId',
        catalogRepository: repository,
      );
      await settle(tester);

      repository.result = null;
      await returnToTab(tester);
      expect(find.text('Product unavailable'), findsOneWidget);
    });

    testWidgets('a failed refresh leaves the page in place', (tester) async {
      final repository = _FailingAfterFirst(sized);
      await pumpStorefront(
        tester,
        catalogue: () async => [sized],
        location: '/product/$testProductId',
        catalogRepository: repository,
      );
      await settle(tester);

      await returnToTab(tester);
      expect(find.text('This piece could not be loaded'), findsNothing);
      expect(find.text('Live Linen Shirt'), findsWidgets);
    });
  });

  group('orders', () {
    Future<(ProviderContainer, _StatusOrders)> pumpOrders(
      WidgetTester tester,
    ) async {
      final orders = _StatusOrders();
      final container = await pumpStorefront(
        tester,
        catalogue: () async => const [],
        location: '/account/orders/order-1',
        auth: FakeAuthRepository(session: FakeAuthRepository.customer),
        overrides: [orderRepositoryProvider.overrideWithValue(orders)],
      );
      await settle(tester);
      return (container, orders);
    }

    testWidgets('an open order shows a new status on returning to the tab', (
      tester,
    ) async {
      final (_, orders) = await pumpOrders(tester);
      expect(find.text('05/11/2026 · Pending'), findsOneWidget);

      orders.status = 'shipped';
      await returnToTab(tester);
      expect(find.text('05/11/2026 · Shipped'), findsOneWidget);
    });

    testWidgets('opening an order again fetches it again, once', (
      tester,
    ) async {
      final (container, orders) = await pumpOrders(tester);
      expect(orders.orderCalls, 1);

      orders.status = 'delivered';
      routerOf(container).go('/shop');
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));
      routerOf(container).go('/account/orders/order-1');
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(orders.orderCalls, 2);
      expect(find.text('05/11/2026 · Delivered'), findsOneWidget);
    });
  });

  group('another tab of this browser', () {
    Future<(ProviderContainer, SharedPreferences)> pumpWithStorage(
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = await pumpStorefront(
        tester,
        catalogue: () async => [testProduct()],
        location: '/bag',
        overrides: [bagPreferencesProvider.overrideWithValue(preferences)],
      );
      await settle(tester);
      return (container, preferences);
    }

    testWidgets('its bag change appears on returning to this tab', (
      tester,
    ) async {
      final (container, preferences) = await pumpWithStorage(tester);
      expect(container.read(bagProvider), isEmpty);

      await preferences.setString(
        bagPersistenceKey,
        jsonEncode({
          'version': 1,
          'items': [
            {
              'product_id': testProductId,
              'size': 'M',
              'color': 'Black',
              'quantity': 2,
              'unit_price': 2499,
              'stock_limit': 5,
            },
          ],
        }),
      );
      await returnToTab(tester);

      expect(container.read(bagItemCountProvider), 2);
      expect(find.text('Live Linen Shirt'), findsOneWidget);
    });

    testWidgets('its wishlist change appears on returning to this tab', (
      tester,
    ) async {
      final (container, preferences) = await pumpWithStorage(tester);
      await preferences.setStringList(wishlistGuestKey, [testProductId]);
      await returnToTab(tester);
      expect(container.read(wishlistProvider), {testProductId});
    });

    testWidgets('without browser storage the bag is left alone', (
      tester,
    ) async {
      final container = await pumpStorefront(
        tester,
        catalogue: () async => [testProduct()],
        location: '/bag',
      );
      await settle(tester);
      container
          .read(bagProvider.notifier)
          .add(testProduct(), size: 'M', color: 'Black');
      await returnToTab(tester);
      expect(container.read(bagItemCountProvider), 1);
    });
  });
}

class _FailingAfterFirst extends StorefrontCatalogRepository {
  _FailingAfterFirst(this.first) : super(null);

  final Product first;
  int calls = 0;

  @override
  Future<Product?> fetchById(String id) async {
    calls++;
    if (calls > 1) throw Exception('offline');
    return first;
  }
}

class _StatusOrders extends OrderRepository {
  String status = 'pending';
  int orderCalls = 0;

  @override
  Future<OrderRecord> customerOrder(String id) async {
    orderCalls++;
    return order(status);
  }

  @override
  Future<List<OrderRecord>> customerOrders() async => [order(status)];
}
