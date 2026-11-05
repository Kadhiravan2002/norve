import 'package:flutter/material.dart';
import 'package:norve/core/theme/norve_theme.dart';

import '../widgets/storefront_state_view.dart';

/// Shown when the build has no usable Supabase connection. No products appear
/// here, because the storefront only ever displays live data.
class StorefrontUnavailableApp extends StatelessWidget {
  const StorefrontUnavailableApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NORVÉ — Elevate Your Everyday',
    debugShowCheckedModeBanner: false,
    theme: NorveTheme.light,
    home: const Scaffold(
      key: ValueKey('storefront-unavailable'),
      body: Center(
        child: SingleChildScrollView(
          child: StorefrontMessageView(
            title: 'NORVÉ is temporarily unavailable',
            message: 'We are unable to open the store right now. Please try again shortly.',
          ),
        ),
      ),
    ),
  );
}
