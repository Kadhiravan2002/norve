class SupabaseConfig {
  const SupabaseConfig({
    required this.url,
    required this.publishableKey,
    this.authRedirectUrl = '',
  });

  factory SupabaseConfig.fromEnvironment() => const SupabaseConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    authRedirectUrl: String.fromEnvironment('SUPABASE_AUTH_REDIRECT_URL'),
  );

  final String url;
  final String publishableKey;
  final String authRedirectUrl;

  bool get isConfigured {
    final uri = Uri.tryParse(url);
    final validHost = uri != null && uri.host.isNotEmpty;
    final validScheme =
        uri?.scheme == 'https' ||
        (uri?.scheme == 'http' &&
            {'localhost', '127.0.0.1', '::1'}.contains(uri?.host));
    return validHost &&
        validScheme &&
        publishableKey.startsWith('sb_publishable_');
  }

  String get configurationMessage {
    if (url.isEmpty || publishableKey.isEmpty) {
      return 'Supabase is not configured. Provide SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY at build time.';
    }
    if (!isConfigured) {
      return 'Supabase configuration is invalid. Use a valid project URL and an sb_publishable_ key.';
    }
    return 'Supabase is configured.';
  }
}
