import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/admin/admin_orders_screen.dart';
import 'package:norve/features/orders/order_providers.dart';
import 'package:norve/features/orders/order_repository.dart';

void main() {
  final testOrders = [
    OrderRecord(
      id: 'o-1',
      reference: 'NRV-2026-001',
      email: 'alex@example.com',
      customerName: 'Alex Bennett',
      phone: '9876543210',
      addressLine1: '12 Luxury Ave',
      addressLine2: '',
      city: 'Mumbai',
      region: 'Maharashtra',
      postalCode: '400001',
      subtotal: 4500,
      shipping: 0,
      tax: 0,
      total: 4500,
      status: 'pending',
      paymentStatus: 'pending',
      paymentMethod: 'cod',
      createdAt: DateTime(2026, 10, 10, 10, 30),
      items: const [
        OrderItemSnapshot(
          productName: 'Oxford Cotton Shirt',
          imageUrl: '',
          size: 'M',
          color: 'White',
          quantity: 2,
          unitPrice: 2250,
          lineTotal: 4500,
        ),
      ],
    ),
    OrderRecord(
      id: 'o-2',
      reference: 'NRV-2026-002',
      email: 'clara@example.com',
      customerName: 'Clara Oswald',
      phone: '9876543211',
      addressLine1: '34 Marine Dr',
      addressLine2: '',
      city: 'Mumbai',
      region: 'Maharashtra',
      postalCode: '400020',
      subtotal: 8000,
      shipping: 0,
      tax: 0,
      total: 8000,
      status: 'confirmed',
      paymentStatus: 'pending',
      paymentMethod: 'cod',
      createdAt: DateTime(2026, 10, 12, 14, 0),
      items: const [
        OrderItemSnapshot(
          productName: 'Cashmere Cardigan',
          imageUrl: '',
          size: 'L',
          color: 'Charcoal',
          quantity: 1,
          unitPrice: 8000,
          lineTotal: 8000,
        ),
      ],
    ),
    OrderRecord(
      id: 'o-3',
      reference: 'NRV-2026-003',
      email: 'david@example.com',
      customerName: 'David Miller',
      phone: '9876543212',
      addressLine1: '56 Residency Rd',
      addressLine2: '',
      city: 'Bengaluru',
      region: 'Karnataka',
      postalCode: '560025',
      subtotal: 12000,
      shipping: 0,
      tax: 0,
      total: 12000,
      status: 'delivered',
      paymentStatus: 'collected',
      paymentMethod: 'cod',
      createdAt: DateTime(2026, 10, 14, 16, 45),
      items: const [
        OrderItemSnapshot(
          productName: 'Silk Slip Dress',
          imageUrl: '',
          size: 'S',
          color: 'Chalk',
          quantity: 3,
          unitPrice: 4000,
          lineTotal: 12000,
        ),
      ],
    ),
    OrderRecord(
      id: 'o-4',
      reference: 'NRV-2026-004',
      email: 'elena@example.com',
      customerName: 'Elena Rostova',
      phone: '9876543213',
      addressLine1: '78 Park Street',
      addressLine2: '',
      city: 'Kolkata',
      region: 'West Bengal',
      postalCode: '700016',
      subtotal: 3500,
      shipping: 0,
      tax: 0,
      total: 3500,
      status: 'cancelled',
      paymentStatus: 'pending',
      paymentMethod: 'cod',
      createdAt: DateTime(2026, 10, 15, 9, 15),
      items: const [
        OrderItemSnapshot(
          productName: 'Linen Trousers',
          imageUrl: '',
          size: 'M',
          color: 'Natural',
          quantity: 1,
          unitPrice: 3500,
          lineTotal: 3500,
        ),
      ],
    ),
  ];

  Widget buildApp({
    List<OrderRecord> orders = const [],
    Size viewport = const Size(1280, 900),
  }) {
    return ProviderScope(
      overrides: [
        adminOrdersProvider.overrideWithValue(AsyncData(orders)),
      ],
      child: MaterialApp(
        theme: NorveTheme.light,
        home: const Scaffold(
          body: AdminOrdersScreen(),
        ),
      ),
    );
  }

  testWidgets(
      'AdminOrdersScreen renders Page Header, KPI Summary Row, Status Tabs and Table',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildApp(orders: testOrders));
    await tester.pumpAndSettle();

    // 1. Page Header
    expect(find.text('Orders'), findsOneWidget);
    expect(
      find.text('Track and manage customer orders across your boutique.'),
      findsOneWidget,
    );
    expect(find.text('4 Persisted Orders'), findsOneWidget);

    // 2. Operational KPI Cards
    // Total Orders: 4
    expect(find.text('TOTAL ORDERS'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
    // Total Items: 2 + 1 + 3 + 1 = 7
    expect(find.text('ITEMS ORDERED'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    // Awaiting Fulfillment: pending(1) + confirmed(1) = 2
    expect(find.text('AWAITING FULFILLMENT'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    // Orders Delivered: 1
    expect(find.text('ORDERS DELIVERED'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    // Cancelled Orders: 1
    expect(find.text('CANCELLED ORDERS'), findsOneWidget);

    // 3. Status Tabs Navigation
    expect(find.byKey(const ValueKey('order-tab-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('order-tab-pending')), findsOneWidget);
    expect(find.byKey(const ValueKey('order-tab-delivered')), findsOneWidget);
    expect(find.byKey(const ValueKey('order-tab-cancelled')), findsOneWidget);

    // 4. Data Table Rows
    expect(find.byKey(const ValueKey('admin-order-o-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-order-o-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-order-o-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-order-o-4')), findsOneWidget);

    // Customer Names
    expect(find.text('Alex Bennett'), findsOneWidget);
    expect(find.text('Clara Oswald'), findsOneWidget);
    expect(find.text('David Miller'), findsOneWidget);
    expect(find.text('Elena Rostova'), findsOneWidget);

    // Order References
    expect(find.text('NRV-2026-001'), findsOneWidget);
    expect(find.text('NRV-2026-002'), findsOneWidget);
    expect(find.text('NRV-2026-003'), findsOneWidget);
    expect(find.text('NRV-2026-004'), findsOneWidget);

    // Monetary Values
    expect(find.text('₹4,500'), findsOneWidget);
    expect(find.text('₹8,000'), findsOneWidget);
    expect(find.text('₹12,000'), findsOneWidget);
    expect(find.text('₹3,500'), findsOneWidget);
  });

  testWidgets('Status tabs filter the order list dynamically',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildApp(orders: testOrders));
    await tester.pumpAndSettle();

    // Initially all 4 orders are visible
    expect(find.byKey(const ValueKey('admin-order-o-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-order-o-3')), findsOneWidget);

    // Tap 'Delivered' tab
    await tester.tap(find.byKey(const ValueKey('order-tab-delivered')));
    await tester.pumpAndSettle();

    // Only David Miller's delivered order is visible
    expect(find.byKey(const ValueKey('admin-order-o-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-order-o-1')), findsNothing);
    expect(find.byKey(const ValueKey('admin-order-o-2')), findsNothing);
    expect(find.byKey(const ValueKey('admin-order-o-4')), findsNothing);

    // Scroll and tap 'Cancelled' tab
    await tester.ensureVisible(find.byKey(const ValueKey('order-tab-cancelled')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('order-tab-cancelled')));
    await tester.pumpAndSettle();

    // Only Elena's cancelled order is visible
    expect(find.byKey(const ValueKey('admin-order-o-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-order-o-3')), findsNothing);

    // Scroll and tap 'All Orders' tab
    await tester.ensureVisible(find.byKey(const ValueKey('order-tab-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('order-tab-all')));
    await tester.pumpAndSettle();

    // All 4 orders visible again
    expect(find.byKey(const ValueKey('admin-order-o-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-order-o-4')), findsOneWidget);
  });

  testWidgets('Search query filters by order reference, customer, and product name',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildApp(orders: testOrders));
    await tester.pumpAndSettle();

    // 1. Search by reference '002'
    await tester.enterText(
      find.byKey(const ValueKey('admin-orders-search')),
      '002',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('admin-order-o-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-order-o-1')), findsNothing);

    // 2. Search by product name 'Silk Slip'
    await tester.enterText(
      find.byKey(const ValueKey('admin-orders-search')),
      'Silk Slip',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('admin-order-o-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-order-o-2')), findsNothing);

    // 3. Search non-matching term
    await tester.enterText(
      find.byKey(const ValueKey('admin-orders-search')),
      'NonExistentProduct',
    );
    await tester.pumpAndSettle();

    expect(find.text('No Matching Orders'), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-orders-filters-button')), findsOneWidget);

    // 4. Clear Filters
    await tester.tap(find.byKey(const ValueKey('clear-orders-filters-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('admin-order-o-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-order-o-4')), findsOneWidget);
  });

  testWidgets('Payment filter distinguishes Cash Collected and Pending COD',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildApp(orders: testOrders));
    await tester.pumpAndSettle();

    // Tap payment dropdown
    await tester.tap(find.byKey(const ValueKey('admin-orders-payment-filter')));
    await tester.pumpAndSettle();

    // Select 'Cash Collected'
    await tester.tap(find.text('Cash Collected').last);
    await tester.pumpAndSettle();

    // Only David Miller's order has paymentStatus == 'collected'
    expect(find.byKey(const ValueKey('admin-order-o-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-order-o-1')), findsNothing);
  });

  testWidgets('Pagination splits results according to page size',
      (tester) async {
    // Generate 12 test orders to test pagination with page size 10
    final manyOrders = [
      for (var i = 1; i <= 12; i++)
        OrderRecord(
          id: 'order-page-$i',
          reference: 'NRV-P-$i',
          email: 'user$i@example.com',
          customerName: 'User $i',
          phone: '9876543200',
          addressLine1: '$i Test St',
          addressLine2: '',
          city: 'Mumbai',
          region: 'Maharashtra',
          postalCode: '400001',
          subtotal: 1000,
          shipping: 0,
          tax: 0,
          total: 1000,
          status: 'pending',
          paymentStatus: 'pending',
          paymentMethod: 'cod',
          createdAt: DateTime(2026, 10, i),
          items: const [],
        ),
    ];

    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildApp(orders: manyOrders));
    await tester.pumpAndSettle();

    // Page 1 displays 1–10 of 12 orders
    expect(find.text('Showing 1–10 of 12 orders'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-order-order-page-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-order-order-page-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-order-order-page-11')), findsNothing);

    // Ensure pagination bar is visible before tapping next page
    await tester.ensureVisible(find.byKey(const ValueKey('pagination-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pagination-next')));
    await tester.pumpAndSettle();

    // Page 2 displays 11–12 of 12 orders
    expect(find.text('Showing 11–12 of 12 orders'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-order-order-page-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-order-order-page-12')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-order-order-page-1')), findsNothing);
  });

  testWidgets(
      'Responsive layouts render smoothly on mobile and tablet without overflow',
      (tester) async {
    // 1. Mobile viewport (390 x 844)
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      buildApp(orders: testOrders, viewport: const Size(390, 844)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('4 Persisted Orders'), findsOneWidget);
    expect(find.text('TOTAL ORDERS'), findsOneWidget);

    // 2. Tablet portrait (768 x 546) - DevTools inspection size
    tester.view.physicalSize = const Size(768, 546);
    await tester.pumpWidget(
      buildApp(orders: testOrders, viewport: const Size(768, 546)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('TOTAL ORDERS'), findsOneWidget);

    // 3. Tablet portrait (768 x 1024)
    tester.view.physicalSize = const Size(768, 1024);
    await tester.pumpWidget(
      buildApp(orders: testOrders, viewport: const Size(768, 1024)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // 4. Tablet landscape (1024 x 768)
    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpWidget(
      buildApp(orders: testOrders, viewport: const Size(1024, 768)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('TOTAL ORDERS'), findsOneWidget);
  });

  testWidgets(
      'Orders renders 2-column KPI grid at 390px and 425px mobile widths with equal card widths and consistent row heights',
      (tester) async {
    for (final width in [425.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildApp(orders: testOrders, viewport: Size(width, 844)),
      );
      await tester.pumpAndSettle();

      // Zero exceptions (no RenderFlex overflow)
      expect(tester.takeException(), isNull);

      // Verify all 5 KPI cards are rendered
      final totalOrdersKpi = find.text('TOTAL ORDERS');
      final itemsOrderedKpi = find.text('ITEMS ORDERED');
      final awaitingKpi = find.text('AWAITING FULFILLMENT');
      final deliveredKpi = find.text('ORDERS DELIVERED');
      final cancelledKpi = find.text('CANCELLED ORDERS');

      expect(totalOrdersKpi, findsOneWidget);
      expect(itemsOrderedKpi, findsOneWidget);
      expect(awaitingKpi, findsOneWidget);
      expect(deliveredKpi, findsOneWidget);
      expect(cancelledKpi, findsOneWidget);

      // Find KPI card containers to check dimensions and layout
      Finder findKpiCard(Finder labelFinder) {
        return find.ancestor(
          of: labelFinder,
          matching: find.byType(Container),
        ).first;
      }

      final card0 = findKpiCard(totalOrdersKpi);
      final card1 = findKpiCard(itemsOrderedKpi);
      final card2 = findKpiCard(awaitingKpi);
      final card3 = findKpiCard(deliveredKpi);
      final card4 = findKpiCard(cancelledKpi);

      final pos0 = tester.getTopLeft(card0);
      final pos1 = tester.getTopLeft(card1);
      final pos2 = tester.getTopLeft(card2);
      final pos3 = tester.getTopLeft(card3);
      final pos4 = tester.getTopLeft(card4);

      final size0 = tester.getSize(card0);
      final size1 = tester.getSize(card1);
      final size2 = tester.getSize(card2);
      final size3 = tester.getSize(card3);
      final size4 = tester.getSize(card4);

      // Row 1 (Card 0 & Card 1): same row, equal widths, consistent heights
      expect(pos0.dy, equals(pos1.dy));
      expect(pos0.dx, lessThan(pos1.dx));
      expect(size0.width, equals(size1.width));
      expect(size0.height, equals(size1.height));

      // Row 2 (Card 2 & Card 3): same row, equal widths, consistent heights
      expect(pos2.dy, equals(pos3.dy));
      expect(pos2.dx, lessThan(pos3.dx));
      expect(size2.width, equals(size3.width));
      expect(size2.height, equals(size3.height));
      expect(pos2.dy, greaterThan(pos0.dy));

      // Row 3 (Card 4): below row 2, aligned to column 1, equal card width
      expect(pos4.dy, greaterThan(pos2.dy));
      expect(pos4.dx, equals(pos0.dx));
      expect(size4.width, equals(size0.width));
    }
  });
}
