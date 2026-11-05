import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:norve/core/auth/auth_providers.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/account/customer_data_providers.dart';
import 'package:norve/features/bag/bag_provider.dart';
import 'package:norve/features/orders/order_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data_refresher.dart';
import 'route_guards.dart';
import 'router.dart';

class StorefrontApp extends ConsumerStatefulWidget {
  const StorefrontApp({super.key});

  @override
  ConsumerState<StorefrontApp> createState() => _StorefrontAppState();
}

class _StorefrontAppState extends ConsumerState<StorefrontApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        final refresher = ref.read(storefrontDataRefresherProvider);
        refresher.reloadBrowserData();
        refresher.customerReturned();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(storefrontRouterProvider);
    // Stays alive from startup, so it sees the catalogue's first load.
    ref.watch(storefrontDataRefresherProvider);

    // Same sign-out and account-switch cleanup as the mobile app. The wishlist
    // follows the session itself, so it keeps each customer's saved pieces.
    ref.listen(authSessionProvider, (previous, next) {
      final oldId = previous?.asData?.value?.userId;
      final nextId = next.asData?.value?.userId;
      if (oldId != null && oldId != nextId) {
        ref.read(bagProvider.notifier).clear();
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
