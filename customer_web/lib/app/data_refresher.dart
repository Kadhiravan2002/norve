import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/features/account/customer_data_providers.dart';
import 'package:norve/features/bag/bag_provider.dart';
import 'package:norve/features/orders/order_providers.dart';
import 'package:norve/features/products/product_catalog_provider.dart';
import 'package:norve/features/wishlist/wishlist_provider.dart';

import '../catalog/storefront_catalog_repository.dart';

/// The whole catalogue is a large request, so returning to the tab only
/// refetches it when it is at least this old.
const catalogueRefreshAge = Duration(minutes: 2);

final storefrontClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Brings the page up to date when the customer returns to its tab. This is
/// not real-time: nothing updates while the customer stays on the page.
class StorefrontDataRefresher {
  StorefrontDataRefresher(this._ref);

  final Ref _ref;
  DateTime? _catalogueLoadedAt;

  void catalogueLoaded() =>
      _catalogueLoadedAt = _ref.read(storefrontClockProvider)();

  bool get _catalogueNeedsRefresh {
    final status = _ref.read(catalogLoadStateProvider);
    if (status.phase == CatalogPhase.loading ||
        status.phase == CatalogPhase.saving) {
      return false;
    }
    if (status.hasError) return true;
    final loadedAt = _catalogueLoadedAt;
    if (loadedAt == null) return true;
    final age = _ref.read(storefrontClockProvider)().difference(loadedAt);
    return age >= catalogueRefreshAge;
  }

  Future<void> customerReturned() async {
    // Providers only refetch if a page on screen is using them.
    _ref.invalidate(storefrontProductProvider);
    _ref.invalidate(customerOrdersProvider);
    _ref.invalidate(customerOrderProvider);
    _ref.invalidate(customerProfileProvider);
    _ref.invalidate(customerAddressesProvider);
    if (_catalogueNeedsRefresh) {
      _ref.invalidate(productCategoriesProvider);
      await _ref.read(productCatalogProvider.notifier).refresh();
    }
  }

  /// Picks up bag and wishlist changes made in another tab of this browser.
  Future<void> reloadBrowserData() async {
    final preferences = _ref.read(bagPreferencesProvider);
    if (preferences == null) return;
    try {
      await _ref.read(bagProvider.notifier).flushPersistence();
      await preferences.reload();
      _ref.invalidate(bagProvider);
      _ref.invalidate(wishlistProvider);
    } catch (_) {
      // Browser storage is unavailable, so this tab keeps what it has.
    }
  }
}

final storefrontDataRefresherProvider = Provider<StorefrontDataRefresher>((
  ref,
) {
  final refresher = StorefrontDataRefresher(ref);
  ref.listen(catalogLoadStateProvider, (previous, next) {
    if (next.phase == CatalogPhase.live) refresher.catalogueLoaded();
  });
  return refresher;
});
