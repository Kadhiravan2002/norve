import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:norve/core/auth/auth_providers.dart';
import 'package:norve/features/bag/bag_provider.dart';
import 'package:norve/features/wishlist/wishlist_provider.dart';

const wishlistGuestKey = 'norve_wishlist_guest_v1';
String wishlistUserKey(String userId) => 'norve_wishlist_user_v1_$userId';

/// Mobile's wishlist, saved in this browser so a refresh does not lose it.
///
/// Each customer has their own saved list, which signing out hides and signing
/// back in restores. Pieces saved as a guest join the list at sign-in.
class StorefrontWishlistController extends WishlistController {
  String? _userId;

  @override
  Set<String> build() {
    ref.watch(authSessionProvider.select((s) => s.asData?.value?.userId));
    _userId = ref.read(authRepositoryProvider).currentSession?.userId;

    final preferences = ref.read(bagPreferencesProvider);
    if (preferences == null) return <String>{};
    final guest = preferences.getStringList(wishlistGuestKey) ?? const [];
    final userId = _userId;
    if (userId == null) return guest.toSet();

    final key = wishlistUserKey(userId);
    final saved = {...?preferences.getStringList(key), ...guest};
    if (guest.isNotEmpty) {
      unawaited(preferences.setStringList(key, saved.toList()));
      unawaited(preferences.remove(wishlistGuestKey));
    }
    return saved;
  }

  void _persist() {
    final userId = _userId;
    unawaited(
      ref
          .read(bagPreferencesProvider)
          ?.setStringList(
            userId == null ? wishlistGuestKey : wishlistUserKey(userId),
            state.toList(),
          ),
    );
  }

  @override
  void toggle(String productId) {
    super.toggle(productId);
    _persist();
  }

  @override
  void clear() {
    super.clear();
    _persist();
  }
}
