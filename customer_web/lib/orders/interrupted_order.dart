import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:norve/features/bag/bag_provider.dart';
import 'package:norve/features/orders/order_providers.dart';
import 'package:norve/features/orders/order_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const interruptedOrderKey = 'norve_pending_order_v1';

typedef InterruptedOrderMark = ({int total, DateTime placedAt});

/// Remembers that an order was being placed, in case the page reloads before
/// the answer arrives. A reload loses the quote, and the bag would still be
/// full, so the customer could otherwise order the same pieces twice.
class InterruptedOrderStore {
  const InterruptedOrderStore(this._preferences);

  final SharedPreferences? _preferences;

  Future<void> mark(int total, {DateTime? at}) async {
    await _preferences?.setString(
      interruptedOrderKey,
      jsonEncode({
        'total': total,
        'placed_at': (at ?? DateTime.now()).toUtc().toIso8601String(),
      }),
    );
  }

  Future<void> clear() async => _preferences?.remove(interruptedOrderKey);

  InterruptedOrderMark? read() {
    final saved = _preferences?.getString(interruptedOrderKey);
    if (saved == null) return null;
    try {
      final data = jsonDecode(saved) as Map<String, dynamic>;
      return (
        total: (data['total'] as num).toInt(),
        placedAt: DateTime.parse(data['placed_at'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Finds the order an interrupted placement created, if it went through.
OrderRecord? matchInterruptedOrder(
  List<OrderRecord> orders,
  InterruptedOrderMark mark,
) {
  // Allows for a device clock that differs from the server's.
  final earliest = mark.placedAt.subtract(const Duration(minutes: 5));
  final latest = mark.placedAt.add(const Duration(minutes: 15));
  for (final order in orders) {
    if (order.total == mark.total &&
        order.createdAt.isAfter(earliest) &&
        order.createdAt.isBefore(latest)) {
      return order;
    }
  }
  return null;
}

final interruptedOrderStoreProvider = Provider<InterruptedOrderStore>(
  (ref) => InterruptedOrderStore(ref.watch(bagPreferencesProvider)),
);

/// Runs when checkout opens. Finds nothing, without any request, unless an
/// earlier placement never got its answer.
final interruptedOrderProvider = FutureProvider.autoDispose<OrderRecord?>((
  ref,
) async {
  final store = ref.read(interruptedOrderStoreProvider);
  final mark = store.read();
  if (mark == null) return null;
  try {
    final orders = await ref.read(orderRepositoryProvider).customerOrders();
    final order = matchInterruptedOrder(orders, mark);
    await store.clear();
    if (order != null) {
      await ref.read(bagProvider.notifier).clearAndPersist();
      ref.invalidate(customerOrdersProvider);
    }
    return order;
  } catch (_) {
    // Offline: checkout cannot place an order either, so the check waits.
    return null;
  }
});
