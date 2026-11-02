import 'package:supabase_flutter/supabase_flutter.dart';

class AuthSession {
  const AuthSession({required this.userId, this.email});

  final String userId;
  final String? email;
}

class AuthActionResult {
  const AuthActionResult({
    this.session,
    this.emailConfirmationRequired = false,
  });

  final AuthSession? session;
  final bool emailConfirmationRequired;
}

class AuthRepositoryException implements Exception {
  const AuthRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class AuthRepository {
  AuthSession? get currentSession;
  Stream<AuthSession?> watchSession();
  Stream<AuthChangeEvent?> watchAuthEvents();
  Future<AuthActionResult> signUp({
    required String email,
    required String password,
  });
  Future<AuthActionResult> signIn({
    required String email,
    required String password,
  });
  Future<void> signOut();
  Future<void> sendPasswordReset(String email, {String? redirectTo});
  Future<void> updatePassword(String password);
}

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client, {this.authRedirectUrl});

  final SupabaseClient _client;
  final String? authRedirectUrl;

  AuthSession? _mapUser(User? user) =>
      user == null ? null : AuthSession(userId: user.id, email: user.email);

  @override
  AuthSession? get currentSession =>
      _mapUser(_client.auth.currentSession?.user);

  @override
  Stream<AuthSession?> watchSession() => Stream<AuthSession?>.multi((sink) {
    final subscription = _client.auth.onAuthStateChange.listen(
      (event) => sink.add(_mapUser(event.session?.user)),
      onError: sink.addError,
    );
    sink.add(currentSession);
    sink.onCancel = subscription.cancel;
  });

  @override
  Stream<AuthChangeEvent?> watchAuthEvents() =>
      _client.auth.onAuthStateChange.map((event) => event.event);

  @override
  Future<AuthActionResult> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    return AuthActionResult(
      session: _mapUser(response.session?.user),
      emailConfirmationRequired: response.session == null,
    );
  }

  @override
  Future<AuthActionResult> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return AuthActionResult(session: _mapUser(response.session?.user));
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> sendPasswordReset(String email, {String? redirectTo}) =>
      _client.auth.resetPasswordForEmail(
        email,
        redirectTo:
            redirectTo ??
            (authRedirectUrl == null || authRedirectUrl!.isEmpty
                ? null
                : authRedirectUrl),
      );

  @override
  Future<void> updatePassword(String password) =>
      _client.auth.updateUser(UserAttributes(password: password));
}

class UnavailableAuthRepository implements AuthRepository {
  const UnavailableAuthRepository(this.message);

  final String message;

  Never _unavailable() => throw AuthRepositoryException(message);

  @override
  AuthSession? get currentSession => null;

  @override
  Stream<AuthSession?> watchSession() => Stream<AuthSession?>.value(null);

  @override
  Stream<AuthChangeEvent?> watchAuthEvents() =>
      Stream<AuthChangeEvent?>.value(null);

  @override
  Future<AuthActionResult> signUp({
    required String email,
    required String password,
  }) async => _unavailable();

  @override
  Future<AuthActionResult> signIn({
    required String email,
    required String password,
  }) async => _unavailable();

  @override
  Future<void> signOut() async => _unavailable();

  @override
  Future<void> sendPasswordReset(String email, {String? redirectTo}) async =>
      _unavailable();

  @override
  Future<void> updatePassword(String password) async => _unavailable();
}
