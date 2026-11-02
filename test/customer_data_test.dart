import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/auth/auth_providers.dart';
import 'package:norve/core/auth/auth_repository.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/account/customer_addresses_section.dart';
import 'package:norve/features/account/customer_data_providers.dart';
import 'package:norve/features/account/customer_data_repository.dart';
import 'package:norve/features/account/customer_profile_section.dart';
import 'package:norve/features/bag/bag_provider.dart';
import 'package:norve/features/orders/checkout_screen.dart';
import 'package:norve/features/orders/order_providers.dart';
import 'package:norve/features/orders/order_repository.dart';
import 'package:norve/features/products/product.dart';

class _MemoryCustomerDataRepository extends CustomerDataRepository {
  CustomerProfile? profile;
  List<CustomerAddress> addresses;
  String? failure;
  int _nextId = 1;

  _MemoryCustomerDataRepository({
    this.profile,
    List<CustomerAddress>? addresses,
  }) : addresses = addresses ?? [];

  void _check() {
    if (failure != null) throw StateError(failure!);
  }

  @override
  Future<CustomerProfile?> loadProfile() async {
    _check();
    return profile;
  }

  @override
  Future<CustomerProfile> saveProfile({
    required String fullName,
    required String phone,
  }) async {
    _check();
    profile = CustomerProfile(
      userId: 'customer-1',
      fullName: fullName,
      phone: phone,
    );
    return profile!;
  }

  @override
  Future<List<CustomerAddress>> loadAddresses() async {
    _check();
    return addresses;
  }

  @override
  Future<CustomerAddress> saveAddress(CustomerAddress address) async {
    _check();
    if (address.userId != 'customer-1') {
      throw const CustomerDataRepositoryException('Address owner mismatch.');
    }
    var saved = address.id == null
        ? address.copyWith(id: 'address-${_nextId++}')
        : address;
    if (addresses.isEmpty) saved = saved.copyWith(isDefault: true);
    if (saved.isDefault) {
      addresses = [
        for (final item in addresses) item.copyWith(isDefault: false),
      ];
    }
    addresses = [
      for (final item in addresses)
        if (item.id != saved.id) item,
      saved,
    ];
    return saved;
  }

  @override
  Future<void> setDefaultAddress(String addressId) async {
    _check();
    if (!addresses.any((item) => item.id == addressId)) {
      throw const CustomerDataRepositoryException('Address not found.');
    }
    addresses = [
      for (final item in addresses)
        item.copyWith(isDefault: item.id == addressId),
    ];
  }

  @override
  Future<void> deleteAddress(String addressId) async {
    _check();
    final matches = addresses.where((item) => item.id == addressId).toList();
    final target = matches.isEmpty ? null : matches.first;
    if (target == null) {
      throw const CustomerDataRepositoryException('Address not found.');
    }
    addresses = addresses.where((item) => item.id != addressId).toList();
    if (target.isDefault && addresses.isNotEmpty) {
      addresses = [
        addresses.first.copyWith(isDefault: true),
        ...addresses.skip(1),
      ];
    }
  }
}

class _MemoryOrderRepository extends OrderRepository {
  DeliveryDetails? placedDelivery;

  @override
  Future<CheckoutQuote> createQuote(List<BagItem> items) async => CheckoutQuote(
    id: 'quote-1',
    items: const [
      QuoteItem(
        productId: 'product-1',
        variantId: 'variant-1',
        productName: 'Essential Cotton Tee',
        imageUrl: '',
        size: 'M',
        color: 'Ivory',
        quantity: 1,
        unitPrice: 799,
        lineTotal: 799,
      ),
    ],
    subtotal: 799,
    shipping: 0,
    tax: 0,
    total: 799,
    expiresAt: DateTime.utc(2026, 10, 30).add(const Duration(minutes: 10)),
  );

  @override
  Future<OrderConfirmation> placeCodOrder(
    String quoteId,
    DeliveryDetails delivery,
  ) async {
    placedDelivery = delivery;
    return OrderConfirmation(
      id: 'order-1',
      reference: 'NRV-1234567890',
      subtotal: 799,
      shipping: 0,
      tax: 0,
      total: 799,
      status: 'pending',
      paymentStatus: 'pending',
      createdAt: DateTime.utc(2026, 10, 30),
    );
  }
}

CustomerAddress _address({
  String? id,
  String label = 'Home',
  String name = 'A. Customer',
  bool isDefault = false,
  String userId = 'customer-1',
}) => CustomerAddress(
  id: id,
  userId: userId,
  label: AddressLabel.fromValue(label),
  recipientName: name,
  phone: '+91 9876543210',
  houseFlatBuilding: '12 Ivory House',
  streetArea: 'Crescent Road',
  landmark: 'Near the park',
  city: 'Mumbai',
  state: 'Maharashtra',
  postalCode: '400001',
  country: 'India',
  isDefault: isDefault,
);

Future<void> _pumpCustomerWidget(
  WidgetTester tester, {
  required Widget child,
  required _MemoryCustomerDataRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => Stream.value(
            const AuthSession(
              userId: 'customer-1',
              email: 'customer@example.com',
            ),
          ),
        ),
        customerDataRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: NorveTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(20), child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('checkout back returns to the bag route', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => Stream.value(const AuthSession(userId: 'customer-1')),
        ),
        customerDataRepositoryProvider.overrideWithValue(
          _MemoryCustomerDataRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(bagProvider.notifier)
        .add(
          const Product(
            id: 'product-1',
            name: 'Essential Cotton Tee',
            price: 799,
            imageUrl: '',
            category: 'T-shirts',
            description: 'Cotton',
            sizes: ['M'],
            colors: [ProductColor('Ivory', 0xFFF5F1EA)],
          ),
          size: 'M',
          color: 'Ivory',
        );
    final router = GoRouter(
      initialLocation: '/bag',
      routes: [
        GoRoute(
          path: '/bag',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/checkout'),
                child: const Text('Shopping Bag'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: NorveTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shopping Bag'));
    await tester.pumpAndSettle();
    expect(find.text('Delivery details'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Shopping Bag'), findsOneWidget);

    await tester.tap(find.text('Shopping Bag'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Shopping Bag'), findsOneWidget);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('customer can load and edit profile without changing email', (
    tester,
  ) async {
    final repository = _MemoryCustomerDataRepository(
      profile: const CustomerProfile(
        userId: 'customer-1',
        fullName: 'A. Customer',
        phone: '+91 9876543210',
      ),
    );
    await _pumpCustomerWidget(
      tester,
      repository: repository,
      child: const CustomerProfileSection(
        userId: 'customer-1',
        email: 'customer@example.com',
      ),
    );

    expect(find.text('customer@example.com'), findsOneWidget);
    expect(find.text('A. Customer'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Avery Customer');
    await tester.enterText(find.byType(TextFormField).at(1), '+91 9000012345');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(repository.profile!.fullName, 'Avery Customer');
    expect(repository.profile!.phone, '+91 9000012345');
    expect(find.text('customer@example.com'), findsOneWidget);
    expect(find.text('Profile details saved.'), findsOneWidget);
  });

  testWidgets('profile loading failures show retry feedback', (tester) async {
    final repository = _MemoryCustomerDataRepository()..failure = 'offline';
    await _pumpCustomerWidget(
      tester,
      repository: repository,
      child: const CustomerProfileSection(
        userId: 'customer-1',
        email: 'customer@example.com',
      ),
    );
    expect(find.text('Profile details could not be loaded.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('customer can add and edit a saved address', (tester) async {
    final repository = _MemoryCustomerDataRepository();
    await _pumpCustomerWidget(
      tester,
      repository: repository,
      child: const CustomerAddressesSection(userId: 'customer-1'),
    );

    await tester.tap(find.text('Add Address'));
    await tester.pumpAndSettle();
    final inputs = find.byType(TextFormField);
    await tester.enterText(inputs.at(0), 'A. Customer');
    await tester.enterText(inputs.at(1), '+91 9876543210');
    await tester.enterText(inputs.at(2), '12 Ivory House');
    await tester.enterText(inputs.at(3), 'Crescent Road');
    await tester.enterText(inputs.at(4), 'Near the park');
    await tester.enterText(inputs.at(5), 'Mumbai');
    await tester.enterText(inputs.at(6), 'Maharashtra');
    await tester.enterText(inputs.at(7), '12345');
    await tester.enterText(inputs.at(8), 'India');
    await tester.tap(find.text('Save Address'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid 6-digit Indian PIN code.'), findsOneWidget);
    await tester.enterText(inputs.at(7), '400001');
    await tester.tap(find.text('Save Address'));
    await tester.pumpAndSettle();

    expect(repository.addresses, hasLength(1));
    expect(repository.addresses.single.isDefault, isTrue);
    expect(find.textContaining('Crescent Road'), findsOneWidget);
    expect(find.text('Address saved.'), findsOneWidget);

    await tester.tap(find.byTooltip('Address options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit address'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Avery Customer');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(repository.addresses.single.recipientName, 'Avery Customer');
  });

  testWidgets('default selection and deleting the default keeps one default', (
    tester,
  ) async {
    final repository = _MemoryCustomerDataRepository(
      addresses: [
        _address(id: 'home', isDefault: true),
        _address(id: 'work', label: 'Work', isDefault: false),
      ],
    );
    await _pumpCustomerWidget(
      tester,
      repository: repository,
      child: const CustomerAddressesSection(userId: 'customer-1'),
    );

    final menus = find.byTooltip('Address options');
    await tester.tap(menus.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set as default'));
    await tester.pumpAndSettle();
    expect(
      repository.addresses.where((item) => item.isDefault).single.id,
      'work',
    );

    await tester.tap(find.byTooltip('Address options').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete address'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Address'));
    await tester.pumpAndSettle();
    expect(repository.addresses, hasLength(1));
    expect(repository.addresses.single.id, 'home');
    expect(repository.addresses.single.isDefault, isTrue);
  });

  testWidgets('address provider rejects rows owned by another user', (
    tester,
  ) async {
    final repository = _MemoryCustomerDataRepository(
      addresses: [_address(id: 'foreign', userId: 'customer-2')],
    );
    await _pumpCustomerWidget(
      tester,
      repository: repository,
      child: const CustomerAddressesSection(userId: 'customer-1'),
    );
    expect(find.text('Saved addresses could not be loaded.'), findsOneWidget);
  });

  test('checkout RPC carries saved address snapshot fields', () {
    const delivery = DeliveryDetails(
      customerName: 'A. Customer',
      phone: '+91 9876543210',
      addressLine1: '12 Ivory House',
      addressLine2: 'Crescent Road',
      city: 'Mumbai',
      region: 'Maharashtra',
      postalCode: '400001',
      addressLabel: 'Home',
      streetArea: 'Crescent Road',
      landmark: 'Near the park',
      country: 'India',
    );
    final params = delivery.toRpcParams('quote-1');
    expect(params['p_house_flat_building'], '12 Ivory House');
    expect(params['p_street_area'], 'Crescent Road');
    expect(params['p_landmark'], 'Near the park');
    expect(params['p_country'], 'India');
    expect(params['p_address_label'], 'Home');
  });

  testWidgets('checkout preselects saved default and places its snapshot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 932);
    tester.view.devicePixelRatio = 1;
    final customers = _MemoryCustomerDataRepository(
      addresses: [_address(id: 'address-home', isDefault: true)],
    );
    final orders = _MemoryOrderRepository();
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => Stream.value(
            const AuthSession(
              userId: 'customer-1',
              email: 'customer@example.com',
            ),
          ),
        ),
        customerDataRepositoryProvider.overrideWithValue(customers),
        orderRepositoryProvider.overrideWithValue(orders),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(bagProvider.notifier)
        .add(
          const Product(
            id: 'product-1',
            name: 'Essential Cotton Tee',
            price: 799,
            imageUrl: '',
            category: 'T-shirts',
            description: 'Cotton',
            sizes: ['M'],
            colors: [ProductColor('Ivory', 0xFFF5F1EA)],
          ),
          size: 'M',
          color: 'Ivory',
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: NorveTheme.light,
          home: const Scaffold(body: CheckoutScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Default'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller!
          .text,
      'A. Customer',
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(2))
          .controller!
          .text,
      '12 Ivory House',
    );

    await tester.drag(
      find.byKey(const ValueKey('checkout-scroll')),
      const Offset(0, -1400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-order')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Near the park'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('checkout-scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PopScope<Object?>>(find.byType(PopScope<Object?>).last)
          .canPop,
      isFalse,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('checkout-scroll')), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('checkout-scroll')),
      const Offset(0, 1400),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delivery details'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller!
          .text,
      'A. Customer',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('review-order')),
      700,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('review-order')));
    await tester.tap(find.byKey(const ValueKey('review-order')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('checkout-scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('confirm-cod-order')));
    await tester.tap(find.byKey(const ValueKey('confirm-cod-order')));
    await tester.pumpAndSettle();

    expect(orders.placedDelivery?.addressLine1, '12 Ivory House');
    expect(orders.placedDelivery?.streetArea, 'Crescent Road');
    expect(orders.placedDelivery?.landmark, 'Near the park');
    expect(orders.placedDelivery?.postalCode, '400001');
    expect(container.read(bagProvider), isEmpty);
    expect(find.text('Reference NRV-1234567890'), findsOneWidget);
    final reference = tester.widget<Text>(
      find.byKey(const ValueKey('order-reference')),
    );
    expect(reference.style?.fontFamily, 'Inter');
    expect(reference.style?.decoration, TextDecoration.none);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
