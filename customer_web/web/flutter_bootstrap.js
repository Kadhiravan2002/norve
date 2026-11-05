{{flutter_js}}
{{flutter_build_config}}

// Flutter's default bootstrap swaps any registered service worker for its own,
// which removes itself. Leaving out its settings keeps NORVÉ's sw.js in place.
_flutter.loader.load();
