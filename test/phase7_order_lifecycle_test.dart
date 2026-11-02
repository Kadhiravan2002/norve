import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:norve/features/admin/admin_order_details_screen.dart';
import 'package:norve/features/orders/order_providers.dart';
import 'package:norve/features/orders/order_repository.dart';

OrderRecord _order({
  String status = 'delivered',
  String paymentMethod = 'cod',
  String paymentStatus = 'pending',
}) => OrderRecord(
  id: 'order-1',
  reference: 'NRV-123',
  email: 'customer@example.test',
  customerName: 'Customer',
  phone: '1234567890',
  addressLine1: '1 Example Road',
  addressLine2: '',
  city: 'Mumbai',
  region: 'Maharashtra',
  postalCode: '400001',
  subtotal: 1000,
  shipping: 0,
  tax: 0,
  total: 1000,
  status: status,
  paymentStatus: paymentStatus,
  paymentMethod: paymentMethod,
  createdAt: DateTime.utc(2026),
  items: const [],
);

void main() {
  test('COD order starts with pending collection', () {
    final order = OrderConfirmation.fromJson({
      'id': 'order-1',
      'order_reference': 'NRV-123',
      'subtotal_inr': 1000,
      'shipping_fee_inr': 0,
      'tax_fee_inr': 0,
      'total_inr': 1000,
      'status': 'pending',
      'payment_method': 'cod',
      'payment_status': 'pending',
      'created_at': '2026-10-30T00:00:00Z',
    });
    expect(order.paymentMethod, 'cod');
    expect(order.paymentStatus, 'pending');
  });

  test('order lifecycle permits only the defined next transitions', () {
    expect(isValidOrderTransition('pending', 'confirmed'), isTrue);
    expect(isValidOrderTransition('confirmed', 'processing'), isTrue);
    expect(isValidOrderTransition('processing', 'shipped'), isTrue);
    expect(isValidOrderTransition('shipped', 'out_for_delivery'), isTrue);
    expect(isValidOrderTransition('out_for_delivery', 'delivered'), isTrue);
    expect(isValidOrderTransition('delivered', 'cancelled'), isFalse);
    expect(isValidOrderTransition('cancelled', 'confirmed'), isFalse);
    expect(isValidOrderTransition('confirmed', 'delivered'), isFalse);
  });

  test('cash collection requires delivered COD pending order', () {
    expect(canCollectCodPayment(_order()), isTrue);
    expect(canCollectCodPayment(_order(status: 'shipped')), isFalse);
    expect(canCollectCodPayment(_order(paymentStatus: 'collected')), isFalse);
    expect(canCollectCodPayment(_order(paymentMethod: 'card')), isFalse);
  });

  testWidgets('admin can advance an order and collect COD once', (
    tester,
  ) async {
    final repo = _LifecycleRepository(_order(status: 'delivered'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [orderRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: Scaffold(body: AdminOrderDetailsScreen(orderId: 'order-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('collect-cod-payment')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('collect-cod-payment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm collection'));
    await tester.pumpAndSettle();
    expect(repo.collectionCalls, 1);
    expect(find.byKey(const ValueKey('collect-cod-payment')), findsNothing);
  });

  testWidgets('admin status update uses the lifecycle actions', (tester) async {
    final repo = _LifecycleRepository(_order(status: 'pending'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [orderRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: Scaffold(body: AdminOrderDetailsScreen(orderId: 'order-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmed'));
    await tester.pumpAndSettle();
    expect(repo.statusUpdates, 1);
    expect(find.text('Processing'), findsOneWidget);
  });

  testWidgets('admin cancellation requires confirmation and cannot repeat', (
    tester,
  ) async {
    final repo = _LifecycleRepository(_order(status: 'pending'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [orderRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: Scaffold(body: AdminOrderDetailsScreen(orderId: 'order-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();
    expect(repo.statusUpdates, 0);
    await tester.tap(find.text('Confirm cancellation'));
    await tester.pumpAndSettle();
    expect(repo.statusUpdates, 1);
    expect(find.text('This order is in a final status.'), findsOneWidget);
  });
}

class _LifecycleRepository extends OrderRepository {
  _LifecycleRepository(this.order);
  OrderRecord order;
  int statusUpdates = 0;
  int collectionCalls = 0;

  @override
  Future<OrderRecord> adminOrder(String id) async => order;

  @override
  Future<String> updateOrderStatus(String orderId, String status) async {
    statusUpdates++;
    order = _order(status: status, paymentStatus: order.paymentStatus);
    return status;
  }

  @override
  Future<String> collectCodPayment(String orderId) async {
    collectionCalls++;
    order = _order(status: order.status, paymentStatus: 'collected');
    return 'collected';
  }
}
