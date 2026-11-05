import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:norve/features/orders/order_providers.dart';

/// Refetches orders each time an order page opens, so an administrator's status
/// or payment update appears. Details already loaded stay visible meanwhile.
class RefreshOrdersOnOpen extends ConsumerStatefulWidget {
  const RefreshOrdersOnOpen({super.key, this.orderId, required this.child});

  final String? orderId;
  final Widget child;

  @override
  ConsumerState<RefreshOrdersOnOpen> createState() =>
      _RefreshOrdersOnOpenState();
}

class _RefreshOrdersOnOpenState extends ConsumerState<RefreshOrdersOnOpen> {
  @override
  void initState() {
    super.initState();
    // Anything not loaded yet is about to load, so needs no second request.
    final refreshList = ref.exists(customerOrdersProvider);
    final id = widget.orderId;
    final refreshOrder = id != null && ref.exists(customerOrderProvider(id));
    if (!refreshList && !refreshOrder) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (refreshList) ref.invalidate(customerOrdersProvider);
      if (refreshOrder) ref.invalidate(customerOrderProvider(id));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
