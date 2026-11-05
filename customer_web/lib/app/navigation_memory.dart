import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Remembers where a customer was when they opened a product, so going back
/// returns to the same filtered list at the same scroll position.
class StorefrontNavigationMemory {
  final Map<String, double> _offsets = {};
  String? _productOrigin;

  /// Where the product page's Back link should go. Null on a direct link.
  String? get productOrigin => _productOrigin;

  void rememberProductOrigin(String location, double scrollOffset) {
    _productOrigin = location;
    _offsets[location] = scrollOffset;
  }

  /// Returns the saved position once, so later visits start at the top.
  double takeScrollOffset(String location) => _offsets.remove(location) ?? 0;
}

final storefrontNavigationMemoryProvider = Provider<StorefrontNavigationMemory>(
  (ref) => StorefrontNavigationMemory(),
);
