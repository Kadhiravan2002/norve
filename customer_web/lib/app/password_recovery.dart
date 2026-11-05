import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'route_guards.dart';

/// The site's address. Overridden in tests, where `Uri.base` is a file path.
final siteBaseUriProvider = Provider<Uri>((ref) => Uri.base);

/// Where a reset email should return to: the site the customer is using.
String passwordResetRedirect(Uri base) => '${base.origin}$passwordResetPath';

/// True when [uri] is a reset email's return link, with its code or error.
bool isPasswordRecoveryLink(Uri uri) {
  if (uri.path != passwordResetPath) return false;
  final fragment = Uri.splitQueryString(uri.fragment);
  bool has(String key) =>
      uri.queryParameters.containsKey(key) || fragment.containsKey(key);
  return has('code') ||
      has('access_token') ||
      has('error') ||
      has('error_code');
}

/// Exchanges a reset link for a session. Must run before the app starts.
///
/// Supabase's automatic link handling turns a failed link into a lasting error
/// on the session stream, which would break unrelated pages. Handling it here
/// keeps that failure contained: the reset page sees no session and offers a
/// new link. Other URLs are ignored, so a stray `?code=` does nothing.
Future<void> completePasswordRecoveryLink(GoTrueClient auth, Uri uri) async {
  if (!isPasswordRecoveryLink(uri)) return;
  try {
    await auth.getSessionFromUrl(uri);
  } catch (_) {
    // Expired, already used, or opened in a different browser.
  }
}
