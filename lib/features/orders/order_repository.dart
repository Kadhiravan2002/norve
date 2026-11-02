import 'package:supabase_flutter/supabase_flutter.dart';

import '../bag/bag_provider.dart';

class DeliveryDetails {
  const DeliveryDetails({
    required this.customerName,
    required this.phone,
    required this.addressLine1,
    this.addressLine2 = '',
    required this.city,
    required this.region,
    required this.postalCode,
    this.addressLabel = 'Other',
    this.streetArea = '',
    this.landmark = '',
    this.country = 'India',
  });

  final String customerName;
  final String phone;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String region;
  final String postalCode;
  final String addressLabel;
  final String streetArea;
  final String landmark;
  final String country;

  Map<String, dynamic> toRpcParams(String quoteId) => {
    'p_quote_id': quoteId,
    'p_customer_name': customerName.trim(),
    'p_phone': phone.trim(),
    'p_house_flat_building': addressLine1.trim(),
    'p_street_area': streetArea.trim().isEmpty
        ? addressLine2.trim()
        : streetArea.trim(),
    'p_landmark': landmark.trim(),
    'p_city': city.trim(),
    'p_state': region.trim(),
    'p_postal_code': postalCode.trim(),
    'p_country': country.trim(),
    'p_address_label': addressLabel,
  };
}

class QuoteItem {
  const QuoteItem({
    required this.productId,
    required this.variantId,
    required this.productName,
    required this.imageUrl,
    required this.size,
    required this.color,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String productId;
  final String variantId;
  final String productName;
  final String imageUrl;
  final String size;
  final String color;
  final int quantity;
  final int unitPrice;
  final int lineTotal;

  factory QuoteItem.fromJson(Map<String, dynamic> json) => QuoteItem(
    productId: json['product_id'].toString(),
    variantId: json['variant_id'].toString(),
    productName: json['product_name']?.toString() ?? '',
    imageUrl: json['product_image_url']?.toString() ?? '',
    size: json['size']?.toString() ?? '',
    color: json['color_name']?.toString() ?? '',
    quantity: (json['quantity'] as num).toInt(),
    unitPrice: (json['unit_price_inr'] as num).toInt(),
    lineTotal: (json['line_total_inr'] as num).toInt(),
  );
}

class CheckoutQuote {
  const CheckoutQuote({
    required this.id,
    required this.items,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.total,
    required this.expiresAt,
  });

  final String id;
  final List<QuoteItem> items;
  final int subtotal;
  final int shipping;
  final int tax;
  final int total;
  final DateTime expiresAt;

  factory CheckoutQuote.fromJson(Map<String, dynamic> json) => CheckoutQuote(
    id: json['quote_id'].toString(),
    items: (json['items'] as List)
        .map(
          (item) => QuoteItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    subtotal: (json['subtotal_inr'] as num).toInt(),
    shipping: (json['shipping_fee_inr'] as num).toInt(),
    tax: (json['tax_fee_inr'] as num).toInt(),
    total: (json['total_inr'] as num).toInt(),
    expiresAt: DateTime.parse(json['expires_at'].toString()),
  );
}

class OrderConfirmation {
  const OrderConfirmation({
    required this.id,
    required this.reference,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.total,
    required this.status,
    required this.paymentStatus,
    this.paymentMethod = 'cod',
    required this.createdAt,
  });

  final String id;
  final String reference;
  final int subtotal;
  final int shipping;
  final int tax;
  final int total;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final DateTime createdAt;

  factory OrderConfirmation.fromJson(Map<String, dynamic> json) =>
      OrderConfirmation(
        id: json['id'].toString(),
        reference: json['order_reference'].toString(),
        subtotal: (json['subtotal_inr'] as num).toInt(),
        shipping: (json['shipping_fee_inr'] as num).toInt(),
        tax: (json['tax_fee_inr'] as num).toInt(),
        total: (json['total_inr'] as num).toInt(),
        status: json['status']?.toString() ?? 'pending',
        paymentStatus: json['payment_status']?.toString() ?? 'pending',
        paymentMethod: json['payment_method']?.toString() ?? 'cod',
        createdAt: DateTime.parse(json['created_at'].toString()),
      );
}

class OrderItemSnapshot {
  const OrderItemSnapshot({
    required this.productName,
    required this.imageUrl,
    required this.size,
    required this.color,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String productName;
  final String imageUrl;
  final String size;
  final String color;
  final int quantity;
  final int unitPrice;
  final int lineTotal;

  factory OrderItemSnapshot.fromJson(Map<String, dynamic> json) =>
      OrderItemSnapshot(
        productName: json['product_name']?.toString() ?? '',
        imageUrl: json['product_image_url']?.toString() ?? '',
        size: json['size']?.toString() ?? '',
        color: json['color_name']?.toString() ?? '',
        quantity: (json['quantity'] as num).toInt(),
        unitPrice: (json['unit_price_inr'] as num).toInt(),
        lineTotal: (json['line_total_inr'] as num).toInt(),
      );
}

class OrderRecord {
  const OrderRecord({
    required this.id,
    required this.reference,
    required this.email,
    required this.customerName,
    required this.phone,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.region,
    required this.postalCode,
    this.addressLabel = 'Other',
    this.streetArea = '',
    this.landmark = '',
    this.country = 'India',
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.total,
    required this.status,
    required this.paymentStatus,
    this.paymentMethod = 'cod',
    required this.createdAt,
    required this.items,
  });

  final String id;
  final String reference;
  final String email;
  final String customerName;
  final String phone;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String region;
  final String postalCode;
  final String addressLabel;
  final String streetArea;
  final String landmark;
  final String country;
  final int subtotal;
  final int shipping;
  final int tax;
  final int total;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final DateTime createdAt;
  final List<OrderItemSnapshot> items;

  factory OrderRecord.fromJson(Map<String, dynamic> json) => OrderRecord(
    id: json['id'].toString(),
    reference: json['order_reference']?.toString() ?? '',
    email: json['customer_email']?.toString() ?? '',
    customerName: json['customer_name']?.toString() ?? '',
    phone: json['phone']?.toString() ?? '',
    addressLine1: json['address_line_1']?.toString() ?? '',
    addressLine2: json['address_line_2']?.toString() ?? '',
    city: json['city']?.toString() ?? '',
    region: json['region']?.toString() ?? '',
    postalCode: json['postal_code']?.toString() ?? '',
    addressLabel: json['address_label']?.toString() ?? 'Other',
    streetArea: json['street_area']?.toString() ?? '',
    landmark: json['landmark']?.toString() ?? '',
    country: json['country']?.toString() ?? 'India',
    subtotal: (json['subtotal_inr'] as num).toInt(),
    shipping: (json['shipping_fee_inr'] as num).toInt(),
    tax: (json['tax_fee_inr'] as num).toInt(),
    total: (json['total_inr'] as num).toInt(),
    status: json['status']?.toString() ?? '',
    paymentStatus: json['payment_status']?.toString() ?? 'pending',
    paymentMethod: json['payment_method']?.toString() ?? 'cod',
    createdAt: DateTime.parse(json['created_at'].toString()),
    items: (json['order_items'] as List? ?? const [])
        .map(
          (item) => OrderItemSnapshot.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(),
  );
}

class AdminOrderSummary {
  const AdminOrderSummary({
    required this.totalOrders,
    required this.pendingOrders,
  });

  final int totalOrders;
  final int pendingOrders;
}

class OrderRepositoryException implements Exception {
  const OrderRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class OrderRepository {
  Future<CheckoutQuote> createQuote(List<BagItem> items) =>
      throw UnimplementedError();
  Future<OrderConfirmation> placeCodOrder(
    String quoteId,
    DeliveryDetails delivery,
  ) => throw UnimplementedError();
  Future<List<OrderRecord>> customerOrders() => throw UnimplementedError();
  Future<OrderRecord> customerOrder(String id) => throw UnimplementedError();
  Future<OrderRecord> adminOrder(String id) => throw UnimplementedError();
  Future<List<OrderRecord>> adminOrders() => throw UnimplementedError();
  Future<String> updateOrderStatus(String orderId, String status) =>
      throw UnimplementedError();
  Future<String> collectCodPayment(String orderId) =>
      throw UnimplementedError();
  Future<AdminOrderSummary> adminSummary() => throw UnimplementedError();
}

class SupabaseOrderRepository extends OrderRepository {
  SupabaseOrderRepository(this._client);

  final SupabaseClient? _client;

  static List<Map<String, dynamic>> toRpcItems(List<BagItem> items) => [
    for (final item in items)
      {
        'product_id': item.productId,
        'size': item.size,
        'color_name': item.color,
        'quantity': item.quantity,
      },
  ];

  @override
  Future<CheckoutQuote> createQuote(List<BagItem> items) async {
    if (items.isEmpty) {
      throw const OrderRepositoryException('Your bag is empty.');
    }
    final data = await _requireClient().rpc(
      'create_checkout_quote',
      params: {'p_items': toRpcItems(items)},
    );
    return CheckoutQuote.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<OrderConfirmation> placeCodOrder(
    String quoteId,
    DeliveryDetails delivery,
  ) async {
    final data = await _requireClient().rpc(
      'place_cod_order_with_address',
      params: delivery.toRpcParams(quoteId),
    );
    return OrderConfirmation.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<List<OrderRecord>> customerOrders() async {
    final rows = await _requireClient()
        .from('orders')
        .select(_orderSelect)
        .order('created_at', ascending: false);
    return rows.map(_mapOrder).toList();
  }

  @override
  Future<OrderRecord> customerOrder(String id) async {
    final row = await _requireClient()
        .from('orders')
        .select(_orderSelect)
        .eq('id', id)
        .single();
    return _mapOrder(row);
  }

  @override
  Future<OrderRecord> adminOrder(String id) => customerOrder(id);

  @override
  Future<List<OrderRecord>> adminOrders() async {
    final rows = await _requireClient()
        .from('orders')
        .select(_orderSelect)
        .order('created_at', ascending: false)
        .limit(300);
    return rows.map(_mapOrder).toList();
  }

  @override
  Future<String> updateOrderStatus(String orderId, String status) async {
    final result = await _requireClient().rpc(
      'admin_update_order_status',
      params: {'p_order_id': orderId, 'p_new_status': status},
    );
    return result.toString();
  }

  @override
  Future<AdminOrderSummary> adminSummary() async {
    final result = await _requireClient().rpc('admin_order_summary');
    final summary = Map<String, dynamic>.from(result as Map);
    return AdminOrderSummary(
      totalOrders: (summary['total_orders'] as num).toInt(),
      pendingOrders: (summary['pending_orders'] as num).toInt(),
    );
  }

  OrderRecord _mapOrder(Map<String, dynamic> row) =>
      OrderRecord.fromJson(Map<String, dynamic>.from(row));

  static const _orderSelect =
      'id,order_reference,customer_email,customer_name,phone,address_label,address_line_1,address_line_2,street_area,landmark,city,region,postal_code,country,subtotal_inr,shipping_fee_inr,tax_fee_inr,total_inr,status,payment_method,payment_status,created_at,order_items(id,product_name,product_image_url,size,color_name,quantity,unit_price_inr,line_total_inr)';

  @override
  Future<String> collectCodPayment(String orderId) async {
    final result = await _requireClient().rpc(
      'admin_mark_cod_collected',
      params: {'p_order_id': orderId},
    );
    return result.toString();
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const OrderRepositoryException(
        'Orders are unavailable until Supabase is configured.',
      );
    }
    return client;
  }
}

int inrValue(dynamic value) => (value as num).toInt();

String orderStatusLabel(String status) => switch (status) {
  'pending' => 'Pending',
  'confirmed' => 'Confirmed',
  'processing' => 'Processing',
  'shipped' => 'Shipped',
  'out_for_delivery' => 'Out for Delivery',
  'delivered' => 'Delivered',
  'cancelled' => 'Cancelled',
  _ => 'Unknown',
};

String paymentStatusLabel(String status) => switch (status) {
  'pending' => 'Pending collection',
  'collected' => 'Cash collected',
  _ => 'Unknown',
};

const orderStatuses = [
  'pending',
  'confirmed',
  'processing',
  'shipped',
  'out_for_delivery',
  'delivered',
  'cancelled',
];

List<String> nextOrderStatuses(String status) => switch (status) {
  'pending' => ['confirmed', 'cancelled'],
  'confirmed' => ['processing', 'cancelled'],
  'processing' => ['shipped', 'cancelled'],
  'shipped' => ['out_for_delivery'],
  'out_for_delivery' => ['delivered'],
  _ => const [],
};

bool isValidOrderTransition(String current, String next) =>
    nextOrderStatuses(current).contains(next);

bool canCollectCodPayment(OrderRecord order) =>
    order.paymentMethod == 'cod' &&
    order.paymentStatus == 'pending' &&
    order.status == 'delivered';
