import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:norve/features/orders/checkout_screen.dart';
import 'package:norve/core/auth/auth_providers.dart';
import 'package:norve/core/auth/auth_repository.dart';
import 'package:norve/features/bag/bag_provider.dart';
import 'package:norve/features/orders/order_providers.dart';
import 'package:norve/features/orders/order_repository.dart';
import 'package:norve/features/products/product.dart';

class _FakeOrderRepository extends OrderRepository {
  Completer<OrderConfirmation>? placeCompleter;
  Object? placeError;
  int placeCalls = 0;

  @override
  Future<OrderConfirmation> placeCodOrder(
    String quoteId,
    DeliveryDetails delivery,
  ) async {
    placeCalls++;
    if (placeError != null) throw placeError!;
    if (placeCompleter != null) return placeCompleter!.future;
    return _confirmation;
  }
}

const _delivery = DeliveryDetails(
  customerName: 'A Customer',
  phone: '+91 9876543210',
  addressLine1: '12 Ivory Lane',
  city: 'Mumbai',
  region: 'Maharashtra',
  postalCode: '400001',
);

final _confirmation = OrderConfirmation(
  id: 'order-1',
  reference: 'NRV-1234567890',
  subtotal: 799,
  shipping: 0,
  tax: 0,
  total: 799,
  status: 'pending',
  paymentStatus: 'pending',
  createdAt: DateTime.utc(2026, 10, 29),
);

Product _product() => const Product(
  id: 'product-1',
  name: 'Essential Cotton Tee',
  price: 799,
  imageUrl: 'https://example.com/tee.jpg',
  category: 'T-shirts',
  description: 'Cotton tee',
  sizes: ['M'],
  colors: [ProductColor('Ivory', 0xFFF5F1EA)],
);

ProviderContainer _container(
  _FakeOrderRepository repository, {
  SharedPreferences? preferences,
}) {
  final container = ProviderContainer(
    overrides: [
      orderRepositoryProvider.overrideWithValue(repository),
      bagPreferencesProvider.overrideWithValue(preferences),
    ],
  );
  container
      .read(bagProvider.notifier)
      .add(_product(), size: 'M', color: 'Ivory');
  return container;
}

void main() {
  test(
    'bag restores IDs and selections, then persists quantity and removal',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final firstSession = ProviderContainer(
        overrides: [bagPreferencesProvider.overrideWithValue(preferences)],
      );
      final firstController = firstSession.read(bagProvider.notifier);
      firstController.add(
        _product(),
        size: 'M',
        color: 'Ivory',
        quantity: 2,
        selectedVariantId: 'variant-db-1',
        stockLimit: 4,
      );
      await firstController.flushPersistence();
      firstSession.dispose();

      final restoredSession = ProviderContainer(
        overrides: [bagPreferencesProvider.overrideWithValue(preferences)],
      );
      final restoredController = restoredSession.read(bagProvider.notifier);
      final restoredItem = restoredSession.read(bagProvider).single;
      expect(restoredItem.productId, 'product-1');
      expect(restoredItem.selectedVariantId, 'variant-db-1');
      expect(restoredItem.variantId, 'variant-db-1');
      expect(restoredItem.size, 'M');
      expect(restoredItem.color, 'Ivory');
      expect(restoredItem.quantity, 2);

      restoredController.increase('variant-db-1');
      await restoredController.flushPersistence();
      restoredSession.dispose();

      final afterQuantityChange = ProviderContainer(
        overrides: [bagPreferencesProvider.overrideWithValue(preferences)],
      );
      expect(afterQuantityChange.read(bagProvider).single.quantity, 3);
      final afterChangeController = afterQuantityChange.read(
        bagProvider.notifier,
      );
      afterChangeController.remove('variant-db-1');
      await afterChangeController.flushPersistence();
      afterQuantityChange.dispose();

      final afterRemoval = ProviderContainer(
        overrides: [bagPreferencesProvider.overrideWithValue(preferences)],
      );
      expect(afterRemoval.read(bagProvider), isEmpty);
      afterRemoval.dispose();
    },
  );

  test('malformed persisted bag data restores as an empty bag', () async {
    SharedPreferences.setMockInitialValues({bagPersistenceKey: 'not-json'});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [bagPreferencesProvider.overrideWithValue(preferences)],
    );
    expect(container.read(bagProvider), isEmpty);
    container.dispose();
  });

  testWidgets('checkout with an empty bag offers shopping navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(const AuthSession(userId: 'customer-1')),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: CheckoutScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your bag is empty.'), findsOneWidget);
    expect(find.text('Continue Shopping'), findsOneWidget);
  });

  test(
    'checkout RPC items contain selections and quantity, never client price',
    () {
      final mapped = SupabaseOrderRepository.toRpcItems([
        const BagItem(
          productId: 'product-1',
          size: 'M',
          color: 'Ivory',
          quantity: 2,
          unitPrice: 799,
        ),
      ]);

      expect(mapped.single, {
        'product_id': 'product-1',
        'size': 'M',
        'color_name': 'Ivory',
        'quantity': 2,
      });
      expect(mapped.single.containsKey('unit_price_inr'), isFalse);
      expect(mapped.single.containsKey('total'), isFalse);
    },
  );

  test('failed order submission preserves the bag', () async {
    final repository = _FakeOrderRepository()
      ..placeError = StateError('inventory changed');
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = _container(repository, preferences: preferences);
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(checkoutControllerProvider.notifier)
          .placeOrder('quote-1', _delivery),
      throwsA(isA<StateError>()),
    );

    expect(container.read(bagProvider), hasLength(1));
    await container.read(bagProvider.notifier).flushPersistence();
    expect(
      (jsonDecode(preferences.getString(bagPersistenceKey)!) as Map)['items'],
      hasLength(1),
    );
    expect(
      container.read(checkoutControllerProvider).error,
      contains('inventory changed'),
    );
  });

  test('successful order clears the bag only after confirmation', () async {
    final repository = _FakeOrderRepository();
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = _container(repository, preferences: preferences);
    addTearDown(container.dispose);

    final result = await container
        .read(checkoutControllerProvider.notifier)
        .placeOrder('quote-1', _delivery);

    expect(result.reference, 'NRV-1234567890');
    expect(container.read(bagProvider), isEmpty);
    await container.read(bagProvider.notifier).flushPersistence();
    expect(
      (jsonDecode(preferences.getString(bagPersistenceKey)!) as Map)['items'],
      isEmpty,
    );
    expect(
      container.read(checkoutControllerProvider).confirmation,
      same(result),
    );
  });

  test(
    'duplicate submissions are rejected while the first request is pending',
    () async {
      final repository = _FakeOrderRepository()
        ..placeCompleter = Completer<OrderConfirmation>();
      final container = _container(repository);
      addTearDown(container.dispose);
      final controller = container.read(checkoutControllerProvider.notifier);

      final first = controller.placeOrder('quote-1', _delivery);
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        controller.placeOrder('quote-1', _delivery),
        throwsA(isA<DuplicateCheckoutSubmissionException>()),
      );
      expect(repository.placeCalls, 1);
      expect(container.read(bagProvider), hasLength(1));

      repository.placeCompleter!.complete(_confirmation);
      await first;
      expect(container.read(bagProvider), isEmpty);
    },
  );
}
