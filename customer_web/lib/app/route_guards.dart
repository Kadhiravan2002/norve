/// Accepts only same-site paths, so `from` cannot redirect off the storefront.
String? safeReturnPath(String? value) {
  if (value == null || !value.startsWith('/')) return null;
  if (value.startsWith('//') || value.contains('\\')) return null;
  return value;
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

  if (path == '/admin' || path.startsWith('/admin/')) return adminNotice;
  if (isAdministrator == true) return path == adminNotice ? null : adminNotice;

  if (!signedIn && _requiresSignIn(path)) {
    return Uri(
      path: '/account',
      queryParameters: {'from': uri.toString()},
    ).toString();
  }
  if (signedIn && path == '/account') {
    return safeReturnPath(uri.queryParameters['from']);
  }
  return null;
}
