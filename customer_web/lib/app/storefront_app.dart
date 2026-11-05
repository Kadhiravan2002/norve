import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:norve/core/auth/auth_providers.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/account/customer_data_providers.dart';
import 'package:norve/features/bag/bag_provider.dart';
import 'package:norve/features/orders/order_providers.dart';
import 'package:norve/features/wishlist/wishlist_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'route_guards.dart';
import 'router.dart';

class StorefrontApp extends ConsumerWidget {
  const StorefrontApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(storefrontRouterProvider);

    // Same sign-out and account-switch cleanup as the mobile app.
    ref.listen(authSessionProvider, (previous, next) {
      final oldId = previous?.asData?.value?.userId;
      final nextId = next.asData?.value?.userId;
      if (oldId != null && oldId != nextId) {
        ref.read(bagProvider.notifier).clear();
        ref.read(wishlistProvider.notifier).clear();
        ref.read(checkoutControllerProvider.notifier).reset();
        ref.invalidate(customerProfileProvider(oldId));
        ref.invalidate(customerAddressesProvider(oldId));
        ref.invalidate(customerOrdersProvider);
        ref.invalidate(customerOrderProvider);
      }
    });
    ref.listen(authEventsProvider, (previous, next) {
      if (next.asData?.value == AuthChangeEvent.passwordRecovery) {
        router.go(passwordResetPath);
      }
    });

    return MaterialApp.router(
      title: 'NORVÉ — Elevate Your Everyday',
      debugShowCheckedModeBanner: false,
      theme: NorveTheme.light,
      routerConfig: router,
    );
  }
}
