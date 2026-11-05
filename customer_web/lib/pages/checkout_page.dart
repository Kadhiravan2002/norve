import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/orders/checkout_screen.dart';
import 'package:norve/features/orders/order_providers.dart';
import 'package:norve/features/orders/order_repository.dart';
import 'package:norve/features/products/product.dart';

import '../app/breakpoints.dart';
import '../orders/interrupted_order.dart';
import '../widgets/storefront_state_view.dart';

/// Mobile's checkout in a branded frame, with a way back on wide screens, where
/// the screen has none of its own.
class CheckoutPage extends ConsumerWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interrupted = ref.watch(interruptedOrderProvider);
    final recovered = interrupted.asData?.value;
    final confirmed =
        ref.watch(checkoutControllerProvider).confirmation != null;
    final showBack =
        !StorefrontBreakpoints.isPhone(MediaQuery.sizeOf(context).width) &&
        !confirmed &&
        recovered == null;

    return Scaffold(
      backgroundColor: NorveColors.ivory,
      body: Column(
        children: [
          _CheckoutHeader(showBack: showBack),
          const Divider(),
          Expanded(
            child: Semantics(
              container: true,
              child: interrupted.isLoading
                  ? const SingleChildScrollView(
                      child: StorefrontLoadingView(
                        label: 'Checking your last order',
                      ),
                    )
                  : recovered != null
                  ? _RecoveredOrder(order: recovered)
                  : const CheckoutScreen(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutHeader extends StatelessWidget {
  const _CheckoutHeader({required this.showBack});

  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final gutter = StorefrontBreakpoints.gutter(
      MediaQuery.sizeOf(context).width,
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 8),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Semantics(
              link: true,
              label: 'NORVÉ home',
              excludeSemantics: true,
              child: InkWell(
                key: const ValueKey('checkout-home'),
                onTap: () => context.go('/'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'NORVÉ',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      letterSpacing: 4.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            if (showBack)
              TextButton.icon(
                key: const ValueKey('checkout-back-to-bag'),
                onPressed: () => context.go('/bag'),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back to Bag'),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecoveredOrder extends StatelessWidget {
  const _RecoveredOrder({required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: StorefrontMessageView(
      key: const ValueKey('checkout-order-recovered'),
      icon: Icons.check_circle_outline,
      title: 'Your order went through',
      message:
          'The page reloaded while your order was being placed, and we '
          'received it. Reference ${order.reference}, total '
          '${formatInr(order.total)}, Cash on Delivery. You do not need to '
          'order again.',
      actionLabel: 'View Your Order',
      onAction: () => context.go('/account/orders/${order.id}'),
    ),
  );
}
