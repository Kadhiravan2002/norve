import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registers NORVÉ's bundled fonts under the plain family names the shared
/// theme and screens request.
///
/// Fonts declared by the `norve` package are namespaced as `packages/norve/…`
/// in a dependent app, so `fontFamily: 'Inter'` would otherwise fall back.
Future<void> loadNorveFonts() async {
  try {
    await Future.wait([
      (FontLoader('Inter')
            ..addFont(rootBundle.load('packages/norve/assets/fonts/Inter.ttf')))
          .load(),
      (FontLoader('PlayfairDisplay')..addFont(
            rootBundle.load('packages/norve/assets/fonts/PlayfairDisplay.ttf'),
          ))
          .load(),
    ]);
  } catch (error) {
    debugPrint('NORVÉ fonts could not be loaded: $error');
  }
}
