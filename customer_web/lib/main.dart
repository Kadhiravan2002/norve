import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/supabase/supabase_config.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/features/bag/bag_provider.dart';
import 'package:norve/features/orders/order_providers.dart';
import 'package:norve/features/orders/order_repository.dart';
import 'package:norve/features/wishlist/wishlist_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/fonts.dart';
import 'app/password_recovery.dart';
import 'app/provider_retry.dart';
import 'app/storefront_app.dart';
import 'orders/interrupted_order.dart';
import 'orders/storefront_order_repository.dart';
import 'pages/storefront_unavailable_app.dart';
import 'wishlist/storefront_wishlist.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  // Reused screens navigate with context.push; keep the address bar accurate.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  await loadNorveFonts();

  // Fail closed: the shared catalogue provider falls back to development
  // fixtures when it has no client, so the storefront never starts without one.
  final config = SupabaseConfig.fromEnvironment();
  if (!config.isConfigured) {
    runApp(const StorefrontUnavailableApp());
    return;
  }

  final SupabaseClient client;
  try {
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.publishableKey,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
    client = Supabase.instance.client;
    await completePasswordRecoveryLink(client.auth, Uri.base);
  } catch (_) {
    runApp(const StorefrontUnavailableApp());
    return;
  }

  SharedPreferences? bagPreferences;
  try {
    bagPreferences = await SharedPreferences.getInstance();
  } catch (_) {
    debugPrint('Local bag persistence is unavailable for this session.');
  }

  runApp(
    ProviderScope(
      retry: storefrontProviderRetry,
      overrides: [
        supabaseConfigProvider.overrideWithValue(config),
        supabaseClientProvider.overrideWithValue(client),
        bagPreferencesProvider.overrideWithValue(bagPreferences),
        wishlistProvider.overrideWith(StorefrontWishlistController.new),
        orderRepositoryProvider.overrideWith(
          (ref) => StorefrontOrderRepository(
            SupabaseOrderRepository(client),
            ref.watch(interruptedOrderStoreProvider),
          ),
        ),
      ],
      child: const StorefrontApp(),
    ),
  );
}
