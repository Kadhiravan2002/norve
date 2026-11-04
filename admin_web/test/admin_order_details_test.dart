import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/features/admin/admin_order_details_screen.dart';
import 'package:norve/features/orders/order_providers.dart';
import 'package:norve/features/orders/order_repository.dart';

class _FakeOrderRepository extends OrderRepository {
  _FakeOrderRepository(this.order);

  OrderRecord order;
  int statusUpdates = 0;
  int collectionCalls = 0;

  @override
  Future<OrderRecord> adminOrder(String id) async => order;

  @override
  Future<String> updateOrderStatus(String orderId, String status) async {
    statusUpdates++;
    order = OrderRecord(
      id: order.id,
      reference: order.reference,
      email: order.email,
      customerName: order.customerName,
      phone: order.phone,
      addressLine1: order.addressLine1,
      addressLine2: order.addressLine2,
      city: order.city,
      region: order.region,
      postalCode: order.postalCode,
      addressLabel: order.addressLabel,
      streetArea: order.streetArea,
      landmark: order.landmark,
      country: order.country,
      subtotal: order.subtotal,
      shipping: order.shipping,
      tax: order.tax,
      total: order.total,
      status: status,
      paymentStatus: order.paymentStatus,
      paymentMethod: order.paymentMethod,
      createdAt: order.createdAt,
      items: order.items,
    );
    return status;
  }

  @override
  Future<String> collectCodPayment(String orderId) async {
    collectionCalls++;
    order = OrderRecord(
      id: order.id,
      reference: order.reference,
      email: order.email,
      customerName: order.customerName,
      phone: order.phone,
      addressLine1: order.addressLine1,
      addressLine2: order.addressLine2,
      city: order.city,
      region: order.region,
      postalCode: order.postalCode,
      addressLabel: order.addressLabel,
      streetArea: order.streetArea,
      landmark: order.landmark,
      country: order.country,
      subtotal: order.subtotal,
      shipping: order.shipping,
      tax: order.tax,
      total: order.total,
      status: order.status,
      paymentStatus: 'collected',
      paymentMethod: order.paymentMethod,
      createdAt: order.createdAt,
      items: order.items,
    );
    return 'collected';
  }
}

OrderRecord _sampleOrder({
  String status = 'pending',
  String paymentStatus = 'pending',
  String paymentMethod = 'cod',
}) {
  return OrderRecord(
    id: 'ord-101',
    reference: 'NRV-2026-8801',
    email: 'elena.rostova@example.com',
    customerName: 'Elena Rostova',
    phone: '+91 98765 43210',
    addressLine1: 'Penthouse 4B, The Grand Residences',
    addressLine2: 'Worli Sea Face',
    streetArea: 'Worli Sea Face',
    landmark: 'Opposite Coast Guard HQ',
    city: 'Mumbai',
    region: 'Maharashtra',
    postalCode: '400018',
    addressLabel: 'Home',
    country: 'India',
    subtotal: 12500,
    shipping: 0,
    tax: 0,
    total: 12500,
    status: status,
    paymentStatus: paymentStatus,
    paymentMethod: paymentMethod,
    createdAt: DateTime(2026, 10, 14, 15, 30),
    items: const [
      OrderItemSnapshot(
        productName: 'Silk Cashmere Trench Coat',
        imageUrl: 'https://example.com/trench.jpg',
        size: 'M',
        color: 'Camel',
        quantity: 1,
        unitPrice: 12500,
        lineTotal: 12500,
      ),
    ],
  );
}

void main() {
  testWidgets('renders order details in two-column desktop layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = _FakeOrderRepository(_sampleOrder());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [orderRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: Scaffold(body: AdminOrderDetailsScreen(orderId: 'ord-101')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Header
    expect(find.text('NRV-2026-8801'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Back to Orders'), findsOneWidget);

    // Verify Order Items Card
    expect(find.text('Items'), findsOneWidget);
    expect(find.text('Silk Cashmere Trench Coat'), findsOneWidget);
    expect(find.text('M · Camel'), findsOneWidget);
    expect(find.text('Qty: 1'), findsOneWidget);

    // Verify Customer Card
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Elena Rostova'), findsOneWidget);
    expect(find.text('elena.rostova@example.com'), findsOneWidget);

    // Verify Delivery Address Card
    expect(find.text('Delivery address'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.textContaining('Worli Sea Face'), findsWidgets);

    // Verify Progression Timeline Card
    expect(find.text('Order Progression'), findsOneWidget);
    expect(find.text('Order Placed'), findsOneWidget);
    expect(find.text('Order Confirmed'), findsOneWidget);

    // Verify Fulfillment Actions Card
    expect(find.text('Update order status'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);

    // Verify Financial Summary Card
    expect(find.text('Financial Summary'), findsOneWidget);
    expect(find.text('Items subtotal'), findsOneWidget);
    expect(find.text('Order total'), findsOneWidget);

    // Verify Payment Details Card
    expect(find.text('Payment Details'), findsOneWidget);
    expect(find.text('Cash on Delivery'), findsOneWidget);
    expect(find.text('Pending COD'), findsOneWidget);
  });

  testWidgets('renders responsive single stacked layout on tablet/mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = _FakeOrderRepository(_sampleOrder());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [orderRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: Scaffold(body: AdminOrderDetailsScreen(orderId: 'ord-101')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Key cards are present and stacked cleanly
    expect(find.text('NRV-2026-8801'), findsOneWidget);
    expect(find.text('Update order status'), findsOneWidget);
    expect(find.text('Items'), findsOneWidget);
    expect(find.text('Financial Summary'), findsOneWidget);
    expect(find.text('Payment Details'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
  });

  testWidgets('allows advancing order status and collecting COD payment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = _FakeOrderRepository(
      _sampleOrder(status: 'delivered', paymentStatus: 'pending'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [orderRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: Scaffold(body: AdminOrderDetailsScreen(orderId: 'ord-101')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // COD button appears for delivered + pending COD
    final codButton = find.byKey(const ValueKey('collect-cod-payment'));
    expect(codButton, findsOneWidget);

    await tester.tap(codButton);
    await tester.pumpAndSettle();

    expect(find.text('Confirm cash collection'), findsOneWidget);
    await tester.tap(find.text('Confirm collection'));
    await tester.pumpAndSettle();

    expect(repo.collectionCalls, 1);
    expect(find.byKey(const ValueKey('collect-cod-payment')), findsNothing);
    expect(find.text('Cash Collected'), findsWidgets);
  });

  testWidgets('displays final status message when order is cancelled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = _FakeOrderRepository(_sampleOrder(status: 'cancelled'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [orderRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: Scaffold(body: AdminOrderDetailsScreen(orderId: 'ord-101')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This order is in a final status.'), findsOneWidget);
    expect(
      find.text(
        'Order was cancelled. No further fulfillment actions can be performed.',
      ),
      findsOneWidget,
    );
  });
}
