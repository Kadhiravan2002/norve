import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/bag/bag_provider.dart';
import 'core/supabase/supabase_config.dart';
import 'core/supabase/supabase_providers.dart';
import 'app/norve_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences? bagPreferences;
  try {
    bagPreferences = await SharedPreferences.getInstance();
  } catch (_) {
    debugPrint('Local bag persistence is unavailable for this session.');
  }
  final config = SupabaseConfig.fromEnvironment();
  SupabaseClient? client;
  String? startupError;
  if (config.isConfigured) {
    try {
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.publishableKey,
      );
      client = Supabase.instance.client;
    } catch (_) {
      startupError = 'Supabase could not be initialized. Verify the project URL, publishable key, and network connection.';
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        supabaseConfigProvider.overrideWithValue(config),
        supabaseClientProvider.overrideWithValue(client),
        supabaseStartupErrorProvider.overrideWithValue(startupError),
        bagPreferencesProvider.overrideWithValue(bagPreferences),
      ],
      child: const NorveApp(),
    ),
  );
}
