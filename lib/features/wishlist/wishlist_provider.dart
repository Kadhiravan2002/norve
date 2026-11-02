import 'package:flutter_riverpod/flutter_riverpod.dart';

class WishlistController extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void toggle(String productId) {
    final next = {...state};
    if (!next.add(productId)) next.remove(productId);
    state = next;
  }

  void clear() => state = <String>{};
}

final wishlistProvider = NotifierProvider<WishlistController, Set<String>>(
  WishlistController.new,
);
