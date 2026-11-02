import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../products/product.dart';

class BagItem {
  const BagItem({
    required this.productId,
    required this.size,
    required this.color,
    required this.quantity,
    required this.unitPrice,
    this.stockLimit = 9999,
    this.selectedVariantId,
  });

  final String productId;
  final String size;
  final String color;
  final int quantity;
  final int unitPrice;
  final int stockLimit;
  final String? selectedVariantId;

  String get variantId => selectedVariantId ?? '$productId|$size|$color';
  int get lineTotal => unitPrice * quantity;

  BagItem withQuantity(int value) => BagItem(
    productId: productId,
    size: size,
    color: color,
    quantity: value,
    unitPrice: unitPrice,
    stockLimit: stockLimit,
    selectedVariantId: selectedVariantId,
  );

  Map<String, Object?> toJson() => {
    'product_id': productId,
    'variant_id': selectedVariantId,
    'size': size,
    'color': color,
    'quantity': quantity,
    'unit_price': unitPrice,
    'stock_limit': stockLimit,
  };

  factory BagItem.fromJson(Map<String, dynamic> json) {
    final productId = json['product_id']?.toString();
    final size = json['size']?.toString();
    final color = json['color']?.toString();
    final quantity = json['quantity'];
    final unitPrice = json['unit_price'];
    final stockLimit = json['stock_limit'];
    if (productId == null ||
        productId.isEmpty ||
        size == null ||
        color == null) {
      throw const FormatException('Saved bag item is missing its selection.');
    }
    if (quantity is! num || unitPrice is! num) {
      throw const FormatException(
        'Saved bag item has invalid quantity or price.',
      );
    }
    final parsedQuantity = quantity.toInt();
    final parsedStockLimit = stockLimit is num ? stockLimit.toInt() : 9999;
    if (parsedQuantity < 1 || unitPrice < 0 || parsedStockLimit < 1) {
      throw const FormatException('Saved bag item contains invalid values.');
    }
    return BagItem(
      productId: productId,
      selectedVariantId: json['variant_id']?.toString(),
      size: size,
      color: color,
      quantity: parsedQuantity.clamp(1, parsedStockLimit),
      unitPrice: unitPrice.toInt(),
      stockLimit: parsedStockLimit,
    );
  }
}

const bagPersistenceKey = 'norve_bag_v1';

final bagPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

class BagController extends Notifier<List<BagItem>> {
  Future<void> _writeQueue = Future<void>.value();

  @override
  List<BagItem> build() => _restore();

  List<BagItem> _restore() {
    final saved = ref
        .read(bagPreferencesProvider)
        ?.getString(bagPersistenceKey);
    if (saved == null || saved.isEmpty) return const [];
    try {
      final decoded = jsonDecode(saved);
      if (decoded is! Map ||
          decoded['version'] != 1 ||
          decoded['items'] is! List) {
        return const [];
      }
      final restored = <BagItem>[];
      for (final rawItem in decoded['items'] as List) {
        if (rawItem is! Map) continue;
        try {
          restored.add(BagItem.fromJson(Map<String, dynamic>.from(rawItem)));
        } on FormatException {
          // Ignore malformed or obsolete lines while preserving valid items.
        }
      }
      return restored;
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  void _setItems(List<BagItem> items) {
    state = items;
    _persist();
  }

  void _persist() {
    final preferences = ref.read(bagPreferencesProvider);
    if (preferences == null) return;
    final snapshot = jsonEncode({
      'version': 1,
      'items': state.map((item) => item.toJson()).toList(),
    });
    _writeQueue = _writeQueue
        .then((_) => preferences.setString(bagPersistenceKey, snapshot))
        .then<void>((_) {})
        .catchError((Object error, StackTrace stackTrace) {
          if (kDebugMode) debugPrint('Local bag persistence failed: $error');
        });
  }

  Future<void> flushPersistence() => _writeQueue;

  void add(
    Product product, {
    required String size,
    required String color,
    int quantity = 1,
    int? unitPrice,
    int? stockLimit,
    String? selectedVariantId,
  }) {
    final index = state.indexWhere(
      (item) =>
          item.productId == product.id &&
          item.size == size &&
          item.color == color,
    );
    if (index < 0) {
      final limit = stockLimit ?? product.stockQuantity;
      if (limit <= 0) return;
      _setItems([
        ...state,
        BagItem(
          productId: product.id,
          selectedVariantId: selectedVariantId,
          size: size,
          color: color,
          quantity: quantity.clamp(1, limit),
          unitPrice: unitPrice ?? product.price,
          stockLimit: limit,
        ),
      ]);
      return;
    }
    final updated = [...state];
    final item = updated[index];
    updated[index] = item.withQuantity(
      (item.quantity + quantity).clamp(1, item.stockLimit),
    );
    _setItems(updated);
  }

  void increase(String variantId) {
    _setItems([
      for (final item in state)
        if (item.variantId == variantId && item.quantity < item.stockLimit)
          item.withQuantity(item.quantity + 1)
        else
          item,
    ]);
  }

  void decrease(String variantId) {
    _setItems([
      for (final item in state)
        if (item.variantId == variantId && item.quantity > 1)
          item.withQuantity(item.quantity - 1)
        else
          item,
    ]);
  }

  void remove(String variantId) {
    _setItems(state.where((item) => item.variantId != variantId).toList());
  }

  void clear() => _setItems(const []);

  Future<void> clearAndPersist() async {
    clear();
    await flushPersistence();
  }
}

final bagProvider = NotifierProvider<BagController, List<BagItem>>(
  BagController.new,
);

final bagItemCountProvider = Provider<int>(
  (ref) =>
      ref.watch(bagProvider).fold(0, (count, item) => count + item.quantity),
);

final bagSubtotalProvider = Provider<int>(
  (ref) => ref.watch(bagProvider).fold(0, (sum, item) => sum + item.lineTotal),
);
