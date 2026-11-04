import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/admin/admin_dashboard_screen.dart';
import 'package:norve/features/orders/order_providers.dart';
import 'package:norve/features/orders/order_repository.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve/features/products/product_catalog_provider.dart';

class _FakeProductCatalogController extends ProductCatalogController {
  _FakeProductCatalogController(this._initial);
  final List<Product> _initial;

  @override
  List<Product> build() => _initial;
}

class _FakeCatalogLoadController extends CatalogLoadController {
  @override
  CatalogLoadState build() => const CatalogLoadState(CatalogPhase.live);
}

void main() {
  testWidgets('AdminDashboardScreen renders all sections, KPIs and tables',
      (tester) async {
    final mockProducts = [
      Product(
        id: 'p-1',
        sku: 'TEST-SKU-1',
        name: 'Oxford Cotton Shirt',
        price: 2499,
        imageUrl: 'https://example.com/img1.jpg',
        category: 'Shirts',
        description: 'Premium shirt',
        stockQuantity: 3, // Low stock threshold is 5
        sizes: const ['M', 'L'],
        colors: const [ProductColor('White', 0xFFFFFFFF)],
      ),
      Product(
        id: 'p-2',
        sku: 'TEST-SKU-2',
        name: 'Cashmere Cardigan',
        price: 4999,
        imageUrl: 'https://example.com/img2.jpg',
        category: 'Knitwear',
        description: 'Soft cashmere knit',
        stockQuantity: 18,
        sizes: const ['One Size'],
        colors: const [ProductColor('Charcoal', 0xFF24211E)],
      ),
    ];

    final mockOrders = [
      OrderRecord(
        id: 'o-1',
        reference: 'ORD-101',
        email: 'customer@example.com',
        customerName: 'Sarah Jenkins',
        phone: '9876543210',
        addressLine1: '42 Baker St',
        addressLine2: '',
        city: 'Mumbai',
        region: 'Maharashtra',
        postalCode: '400001',
        subtotal: 4999,
        shipping: 0,
        tax: 0,
        total: 4999,
        status: 'delivered',
        paymentStatus: 'collected',
        createdAt: DateTime(2026, 10, 15, 14, 30),
        items: const [],
      ),
      OrderRecord(
        id: 'o-2',
        reference: 'ORD-102',
        email: 'priya@example.com',
        customerName: 'Priya Sharma',
        phone: '9876543211',
        addressLine1: '12 Marine Drive',
        addressLine2: '',
        city: 'Mumbai',
        region: 'Maharashtra',
        postalCode: '400020',
        subtotal: 2499,
        shipping: 0,
        tax: 0,
        total: 2499,
        status: 'pending',
        paymentStatus: 'pending',
        createdAt: DateTime(2026, 10, 20, 11, 0),
        items: const [],
      ),
    ];

    const mockSummary = AdminOrderSummary(
      totalOrders: 2,
      pendingOrders: 1,
    );

    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productCatalogProvider.overrideWith(
            () => _FakeProductCatalogController(mockProducts),
          ),
          catalogLoadStateProvider.overrideWith(
            _FakeCatalogLoadController.new,
          ),
          adminOrdersProvider.overrideWithValue(
            AsyncData(mockOrders),
          ),
          adminOrderSummaryProvider.overrideWithValue(
            const AsyncData(mockSummary),
          ),
        ],
        child: MaterialApp(
          theme: NorveTheme.light,
          home: const Scaffold(
            body: AdminDashboardScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Page Header
    expect(find.text('Admin Dashboard'), findsOneWidget);
    expect(
      find.text(
        'Operational summary of catalogue performance, real-time inventory and customer orders.',
      ),
      findsOneWidget,
    );

    // Verify KPI Cards
    expect(find.text('TOTAL PRODUCTS'), findsOneWidget);
    expect(find.text('UNITS IN STOCK'), findsOneWidget);
    expect(find.text('TOTAL ORDERS'), findsOneWidget);
    expect(find.text('LOW-STOCK PRODUCTS'), findsOneWidget);
    expect(find.text('2 active in catalogue'), findsOneWidget);
    expect(find.text('21'), findsOneWidget); // 3 + 18 total units
    expect(find.text('Stock <= 5 units'), findsOneWidget);

    // Verify Sales & Orders Overview
    expect(find.text('Sales & Orders Overview'), findsOneWidget);
    expect(find.text('GROSS ORDER VALUE'), findsOneWidget);
    expect(find.text('AVG. ORDER VALUE'), findsOneWidget);
    expect(find.text('TOTAL TRANSACTIONS'), findsOneWidget);
    expect(find.text('ORDER LIFECYCLE DISTRIBUTION'), findsOneWidget);

    // Verify Recent Orders Table
    expect(find.text('Recent Orders'), findsOneWidget);
    expect(find.text('#ORD-101'), findsOneWidget);
    expect(find.text('#ORD-102'), findsOneWidget);
    expect(find.text('Sarah Jenkins'), findsOneWidget);
    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.text('₹4,999'), findsWidgets);
    expect(find.text('Delivered'), findsWidgets);
    expect(find.text('Pending'), findsWidgets);

    // Verify Settlement Overview (Right Column)
    expect(find.text('Settlement Overview'), findsOneWidget);
    expect(find.text('Gross Order Value'), findsOneWidget);
    expect(find.text('Total value of 2 active orders'), findsOneWidget);
    expect(find.text('Collected Cash on Delivery'), findsOneWidget);
    expect(find.text('Pending Collection'), findsOneWidget);

    // Verify Operational Alerts (Right Column)
    expect(find.text('Operational Alerts'), findsOneWidget);
    expect(find.text('1 Low-Stock Products'), findsOneWidget);
    expect(find.text('1 Orders Awaiting Dispatch'), findsOneWidget);

    // Verify Quick Actions
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Add New Product'), findsOneWidget);
    expect(find.text('Review Stock & Inventory'), findsOneWidget);
    expect(find.text('Manage Categories'), findsOneWidget);
  });

  testWidgets(
      'Settlement overview excludes cancelled orders and low-stock card shows healthy state',
      (tester) async {
    final mockProducts = [
      Product(
        id: 'p-1',
        sku: 'TEST-SKU-1',
        name: 'Oxford Cotton Shirt',
        price: 2499,
        imageUrl: 'https://example.com/img1.jpg',
        category: 'Shirts',
        description: 'Premium shirt',
        stockQuantity: 20, // Optimal stock
        sizes: const ['M'],
        colors: const [ProductColor('White', 0xFFFFFFFF)],
      ),
    ];

    final mockOrders = [
      OrderRecord(
        id: 'o-1',
        reference: 'ORD-101',
        email: 'customer@example.com',
        customerName: 'Sarah Jenkins',
        phone: '9876543210',
        addressLine1: '42 Baker St',
        addressLine2: '',
        city: 'Mumbai',
        region: 'Maharashtra',
        postalCode: '400001',
        subtotal: 5000,
        shipping: 0,
        tax: 0,
        total: 5000,
        status: 'delivered',
        paymentStatus: 'collected',
        createdAt: DateTime(2026, 10, 15, 14, 30),
        items: const [],
      ),
      OrderRecord(
        id: 'o-2',
        reference: 'ORD-102',
        email: 'priya@example.com',
        customerName: 'Priya Sharma',
        phone: '9876543211',
        addressLine1: '12 Marine Drive',
        addressLine2: '',
        city: 'Mumbai',
        region: 'Maharashtra',
        postalCode: '400020',
        subtotal: 2000,
        shipping: 0,
        tax: 0,
        total: 2000,
        status: 'pending',
        paymentStatus: 'pending',
        createdAt: DateTime(2026, 10, 20, 11, 0),
        items: const [],
      ),
      OrderRecord(
        id: 'o-3',
        reference: 'ORD-103',
        email: 'cancelled@example.com',
        customerName: 'Aman Verma',
        phone: '9876543212',
        addressLine1: '7 Colaba',
        addressLine2: '',
        city: 'Mumbai',
        region: 'Maharashtra',
        postalCode: '400005',
        subtotal: 9000,
        shipping: 0,
        tax: 0,
        total: 9000,
        status: 'cancelled',
        paymentStatus: 'pending',
        createdAt: DateTime(2026, 10, 22, 10, 0),
        items: const [],
      ),
    ];

    const mockSummary = AdminOrderSummary(
      totalOrders: 3,
      pendingOrders: 1,
    );

    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productCatalogProvider.overrideWith(
            () => _FakeProductCatalogController(mockProducts),
          ),
          catalogLoadStateProvider.overrideWith(
            _FakeCatalogLoadController.new,
          ),
          adminOrdersProvider.overrideWithValue(
            AsyncData(mockOrders),
          ),
          adminOrderSummaryProvider.overrideWithValue(
            const AsyncData(mockSummary),
          ),
        ],
        child: MaterialApp(
          theme: NorveTheme.light,
          home: const Scaffold(
            body: AdminDashboardScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Low Stock optimal state
    expect(find.text('Inventory levels optimal'), findsOneWidget);

    // Verify Active Orders: only 2 active (ORD-101 and ORD-102), total ₹7,000
    // Cancelled order (ORD-103 of ₹9,000) must be excluded from Gross Order Value
    expect(find.text('₹7,000'), findsWidgets); // Gross: 5000 + 2000
    expect(find.text('Total value of 2 active orders'), findsOneWidget);
    expect(find.text('₹5,000'), findsWidgets); // Collected: 5000
    expect(find.text('₹2,000'), findsWidgets); // Pending: 2000
  });

  testWidgets(
      'AdminDashboardScreen renders responsively on tablet viewports (768px and 1024px)',
      (tester) async {
    final mockProducts = [
      Product(
        id: 'p-1',
        sku: 'TEST-SKU-1',
        name: 'Oxford Cotton Shirt',
        price: 2499,
        imageUrl: 'https://example.com/img1.jpg',
        category: 'Shirts',
        description: 'Premium shirt',
        stockQuantity: 3,
        sizes: const ['M', 'L'],
        colors: const [ProductColor('White', 0xFFFFFFFF)],
      ),
    ];

    const mockSummary = AdminOrderSummary(
      totalOrders: 1,
      pendingOrders: 1,
    );

    Widget buildDashboard() => ProviderScope(
          overrides: [
            productCatalogProvider.overrideWith(
              () => _FakeProductCatalogController(mockProducts),
            ),
            catalogLoadStateProvider.overrideWith(
              _FakeCatalogLoadController.new,
            ),
            adminOrdersProvider.overrideWithValue(
              const AsyncData([]),
            ),
            adminOrderSummaryProvider.overrideWithValue(
              const AsyncData(mockSummary),
            ),
          ],
          child: MaterialApp(
            theme: NorveTheme.light,
            home: const Scaffold(
              body: AdminDashboardScreen(),
            ),
          ),
        );

    // 1. Tablet Portrait at 768 x 546 (manual DevTools inspection size)
    tester.view.physicalSize = const Size(768, 546);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildDashboard());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Admin Dashboard'), findsOneWidget);
    expect(find.text('TOTAL PRODUCTS'), findsOneWidget);

    // 2. Tablet Portrait at 768 x 1024
    tester.view.physicalSize = const Size(768, 1024);
    await tester.pumpWidget(buildDashboard());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 3. Tablet Landscape at 1024 x 768
    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpWidget(buildDashboard());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Quick Actions'), findsOneWidget);
  });

  testWidgets(
      'Dashboard renders 2-column KPI grid at 390px and 425px mobile widths with equal card widths',
      (tester) async {
    final mockProducts = [
      Product(
        id: 'p-1',
        sku: 'TEST-SKU-1',
        name: 'Oxford Cotton Shirt',
        price: 2499,
        imageUrl: 'https://example.com/img1.jpg',
        category: 'Shirts',
        description: 'Premium shirt',
        stockQuantity: 3,
        sizes: const ['M', 'L'],
        colors: const [ProductColor('White', 0xFFFFFFFF)],
      ),
      Product(
        id: 'p-2',
        sku: 'TEST-SKU-2',
        name: 'Cashmere Cardigan',
        price: 4999,
        imageUrl: 'https://example.com/img2.jpg',
        category: 'Knitwear',
        description: 'Soft cashmere knit',
        stockQuantity: 18,
        sizes: const ['One Size'],
        colors: const [ProductColor('Charcoal', 0xFF24211E)],
      ),
    ];

    const mockSummary = AdminOrderSummary(
      totalOrders: 2,
      pendingOrders: 1,
    );

    Widget buildDashboard() => ProviderScope(
          overrides: [
            productCatalogProvider.overrideWith(
              () => _FakeProductCatalogController(mockProducts),
            ),
            catalogLoadStateProvider.overrideWith(
              _FakeCatalogLoadController.new,
            ),
            adminOrdersProvider.overrideWithValue(
              const AsyncData([]),
            ),
            adminOrderSummaryProvider.overrideWithValue(
              const AsyncData(mockSummary),
            ),
          ],
          child: MaterialApp(
            theme: NorveTheme.light,
            home: const Scaffold(
              body: AdminDashboardScreen(),
            ),
          ),
        );

    for (final width in [425.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      // Zero exceptions (no RenderFlex overflow)
      expect(tester.takeException(), isNull);

      // Verify all 4 KPI cards are rendered
      final productKpi = find.text('TOTAL PRODUCTS');
      final stockKpi = find.text('UNITS IN STOCK');
      final ordersKpi = find.text('TOTAL ORDERS');
      final lowStockKpi = find.text('LOW-STOCK PRODUCTS');

      expect(productKpi, findsOneWidget);
      expect(stockKpi, findsOneWidget);
      expect(ordersKpi, findsOneWidget);
      expect(lowStockKpi, findsOneWidget);

      // Verify 2-column layout (Row 1 side-by-side, Row 2 side-by-side)
      final productPos = tester.getTopLeft(productKpi);
      final stockPos = tester.getTopLeft(stockKpi);
      final ordersPos = tester.getTopLeft(ordersKpi);
      final lowStockPos = tester.getTopLeft(lowStockKpi);

      // Row 1 cards share the same vertical alignment
      expect(productPos.dy, equals(stockPos.dy));
      // First card is on the left, second card is on the right
      expect(productPos.dx, lessThan(stockPos.dx));

      // Row 2 cards share the same vertical alignment
      expect(ordersPos.dy, equals(lowStockPos.dy));
      // First card is on the left, second card is on the right
      expect(ordersPos.dx, lessThan(lowStockPos.dx));

      // Row 2 is positioned strictly below Row 1
      expect(ordersPos.dy, greaterThan(productPos.dy));
    }
  });
}
