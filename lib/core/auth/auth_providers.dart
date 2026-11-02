import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_providers.dart';
import 'auth_repository.dart';

final authServicesAvailableProvider = Provider<bool>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final startupError = ref.watch(supabaseStartupErrorProvider);
  return client != null &&
      startupError == null &&
      ref.watch(supabaseConfigProvider).isConfigured;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final startupError = ref.watch(supabaseStartupErrorProvider);
  final config = ref.watch(supabaseConfigProvider);
  if (startupError != null) {
    return UnavailableAuthRepository(startupError);
  }
  if (client == null || !config.isConfigured) {
    return UnavailableAuthRepository(
      'Account services are unavailable. Supabase has not been configured.',
    );
  }
  return SupabaseAuthRepository(
    client,
    authRedirectUrl: config.authRedirectUrl,
  );
});

final authSessionProvider = StreamProvider<AuthSession?>((ref) {
  return ref.watch(authRepositoryProvider).watchSession();
});

final authEventsProvider = StreamProvider((ref) {
  return ref.watch(authRepositoryProvider).watchAuthEvents();
});
