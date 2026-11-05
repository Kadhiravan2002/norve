import 'package:norve/features/bag/bag_provider.dart';
import 'package:norve/features/orders/order_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'interrupted_order.dart';

const _unreachableMessage =
    'We could not reach NORVÉ. Check your connection and try again.';

/// Customer wording for the checkout functions' server errors, which the
/// reused checkout screen would otherwise show as raw database text.
String readableCheckoutError(PostgrestException error) {
  final text = error.message.toLowerCase();
  if (error.code == '28000' ||
      error.code == '42501' ||
      error.code == 'PGRST301' ||
      text.contains('jwt')) {
    return 'Your sign-in could not be verified. Sign in again and retry.';
  }
  if (text.contains('insufficient stock')) {
    return 'There is not enough stock for a piece in your bag. Lower its '
        'quantity in your bag and try again.';
  }
  if (text.contains('unavailable') || text.contains('no longer available')) {
    return 'A piece in your bag is no longer available. Remove it from your '
        'bag and try again.';
  }
  if (text.contains('quote expired') || text.contains('quote was not found')) {
    return 'Your order review has expired. Select Edit Details, then review '
        'your order again.';
  }
  if (text.contains('prices changed')) {
    return 'A price has changed since your review. Select Edit Details, then '
        'review your order again.';
  }
  if (text.contains('stock changed')) {
    return 'Stock has changed since your review. Select Edit Details, then '
        'review your order again.';
  }
  if (text.contains('charges changed')) {
    return 'Delivery or tax charges have changed since your review. Select '
        'Edit Details, then review your order again.';
  }
  if (text.contains('details are invalid')) {
    return 'Some delivery details are not valid. Check them and try again.';
  }
  if (text.contains('between 1 and 50')) {
    return 'Your bag can hold up to 50 different pieces. Remove some and try '
        'again.';
  }
  return 'We could not complete this step. Please try again shortly.';
}

/// Mobile's order calls with readable errors and interruption tracking.
class StorefrontOrderRepository extends OrderRepository {
  StorefrontOrderRepository(this._inner, this._interrupted);

  final OrderRepository _inner;
  final InterruptedOrderStore _interrupted;
  final _quotedTotals = <String, int>{};

  @override
  Future<CheckoutQuote> createQuote(List<BagItem> items) async {
    try {
      final quote = await _inner.createQuote(items);
      _quotedTotals[quote.id] = quote.total;
      return quote;
    } on OrderRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw OrderRepositoryException(readableCheckoutError(error));
    } catch (_) {
      throw const OrderRepositoryException(_unreachableMessage);
    }
  }

  @override
  Future<OrderConfirmation> placeCodOrder(
    String quoteId,
    DeliveryDetails delivery,
  ) async {
    final total = _quotedTotals[quoteId];
    if (total != null) await _interrupted.mark(total);
    try {
      final confirmation = await _inner.placeCodOrder(quoteId, delivery);
      await _interrupted.clear();
      return confirmation;
    } on OrderRepositoryException {
      await _interrupted.clear();
      rethrow;
    } on PostgrestException catch (error) {
      await _interrupted.clear();
      throw OrderRepositoryException(readableCheckoutError(error));
    } catch (_) {
      // The server may have received it, so the marker stays. Repeating the
      // same quote is safe: the server returns the existing order.
      throw const OrderRepositoryException(
        'We could not confirm your order. Check your connection and select '
        'Place COD Order again. This will not create a second order.',
      );
    }
  }

  @override
  Future<List<OrderRecord>> customerOrders() => _inner.customerOrders();

  @override
  Future<OrderRecord> customerOrder(String id) => _inner.customerOrder(id);
}
