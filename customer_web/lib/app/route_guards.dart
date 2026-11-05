const loginPath = '/login';
const registerPath = '/register';
const accountPath = '/account';
const passwordResetPath = '/account/reset-password';

/// Accepts only same-site paths, so `from` cannot redirect off the storefront.
String? safeReturnPath(String? value) {
  if (value == null || !value.startsWith('/')) return null;
  if (value.startsWith('//') || value.contains('\\')) return null;
  return value;
}

/// Builds a sign-in or registration URL that keeps a safe return destination.
String authLocation(String path, String? from) {
  final safe = safeReturnPath(from);
  return Uri(
    path: path,
    queryParameters: safe == null ? null : {'from': safe},
  ).toString();
}

bool _requiresSignIn(String path) =>
    path == '/checkout' ||
    path == '/account/orders' ||
    path.startsWith('/account/orders/');

/// Decides where a browser URL should really go. Returns null to stay.
///
/// [isAdministrator] is null while unresolved. Unknown is never treated as a
/// denial, so guests and customers are not blocked by a slow or failed lookup.
String? storefrontRedirect(
  Uri uri, {
  required bool signedIn,
  required bool? isAdministrator,
}) {
  final path = uri.path;
  const adminNotice = '/administrator-access';

  // A reset link's one-time code is spent by startup, so it leaves the URL.
  if (path == passwordResetPath && (uri.hasQuery || uri.hasFragment)) {
    return passwordResetPath;
  }
  if (path == '/admin' || path.startsWith('/admin/')) return adminNotice;
  if (isAdministrator == true) {
    return path == adminNotice || path == passwordResetPath
        ? null
        : adminNotice;
  }

  final from = uri.queryParameters['from'];
  if (signedIn) {
    if (path == loginPath || path == registerPath) {
      return safeReturnPath(from) ?? accountPath;
    }
    return null;
  }
  if (path == accountPath) return authLocation(loginPath, from);
  if (_requiresSignIn(path)) return authLocation(loginPath, uri.toString());
  return null;
}
