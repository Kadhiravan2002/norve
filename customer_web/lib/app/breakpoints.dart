/// Storefront layout widths, in logical pixels.
abstract final class StorefrontBreakpoints {
  static const tablet = 768.0;
  static const desktop = 1024.0;
  static const contentMaxWidth = 1440.0;

  static bool isPhone(double width) => width < tablet;
  static bool isDesktop(double width) => width >= desktop;

  /// Side gutter keeping content centred and capped at [contentMaxWidth].
  static double gutter(double width) {
    final minimum = isPhone(width) ? 16.0 : 32.0;
    final centred = (width - contentMaxWidth) / 2;
    return centred > minimum ? centred : minimum;
  }
}
