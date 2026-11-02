import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/supabase/supabase_providers.dart';
import '../bag/bag_provider.dart';
import 'order_repository.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return SupabaseOrderRepository(ref.watch(supabaseClientProvider));
});

final customerOrdersProvider = FutureProvider<List<OrderRecord>>((ref) async {
  final session = ref.watch(authSessionProvider).asData?.value;
  if (session == null) {
    throw const OrderRepositoryException('Sign in to view your order history.');
  }
  return ref.watch(orderRepositoryProvider).customerOrders();
});

final customerOrderProvider = FutureProvider.family<OrderRecord, String>((
  ref,
  id,
) async {
  final session = ref.watch(authSessionProvider).asData?.value;
  if (session == null) {
    throw const OrderRepositoryException('Sign in to view this order.');
  }
  return ref.watch(orderRepositoryProvider).customerOrder(id);
});

final adminOrderProvider = FutureProvider.family<OrderRecord, String>((
  ref,
  id,
) {
  return ref.watch(orderRepositoryProvider).adminOrder(id);
});

final adminOrdersProvider = FutureProvider<List<OrderRecord>>((ref) {
  return ref.watch(orderRepositoryProvider).adminOrders();
});

final adminOrderSummaryProvider = FutureProvider<AdminOrderSummary>((ref) {
  return ref.watch(orderRepositoryProvider).adminSummary();
});

class CheckoutSubmissionState {
  const CheckoutSubmissionState({
    this.isSubmitting = false,
    this.error,
    this.confirmation,
  });

  final bool isSubmitting;
  final String? error;
  final OrderConfirmation? confirmation;
}

class DuplicateCheckoutSubmissionException implements Exception {
  const DuplicateCheckoutSubmissionException();
}

class CheckoutController extends Notifier<CheckoutSubmissionState> {
  @override
  CheckoutSubmissionState build() => const CheckoutSubmissionState();

  Future<OrderConfirmation> placeOrder(
    String quoteId,
    DeliveryDetails delivery,
  ) async {
    if (state.isSubmitting) {
      throw const DuplicateCheckoutSubmissionException();
    }
    state = const CheckoutSubmissionState(isSubmitting: true);
    try {
      final confirmation = await ref
          .read(orderRepositoryProvider)
          .placeCodOrder(quoteId, delivery);
      await ref.read(bagProvider.notifier).clearAndPersist();
      state = CheckoutSubmissionState(confirmation: confirmation);
      return confirmation;
    } catch (error) {
      state = CheckoutSubmissionState(error: _messageFor(error));
      rethrow;
    }
  }

  void reset() => state = const CheckoutSubmissionState();

  String _messageFor(Object error) {
    final message = error.toString();
    if (message.contains('42501') ||
        message.toLowerCase().contains('row-level security')) {
      return 'Order authorization was denied. Sign in and try again.';
    }
    if (message.contains('stock') ||
        message.contains('variant') ||
        message.contains('price')) {
      return message.replaceFirst('Exception: ', '');
    }
    return message.replaceFirst('Exception: ', '');
  }
}

final checkoutControllerProvider =
    NotifierProvider<CheckoutController, CheckoutSubmissionState>(
      CheckoutController.new,
    );
