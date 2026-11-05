import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/auth/auth_providers.dart';
import 'package:norve/core/auth/auth_repository.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/password_recovery.dart';
import '../app/route_guards.dart';
import '../shell/storefront_footer.dart';

enum AuthPageMode { signIn, register }

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Plain wording for Supabase's auth failures, without raw server text.
String authErrorMessage(Object error) {
  if (error is AuthRepositoryException) return error.message;
  if (error is AuthRetryableFetchException) return _connectionMessage;
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'That email or password is not correct.';
      case 'user_already_exists':
      case 'email_exists':
        return 'An account with this email already exists. Sign in instead.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Too many attempts. Please wait a while and try again.';
    }
    final status = int.tryParse(error.statusCode ?? '');
    if (status != null && status >= 500) return _connectionMessage;
    return error.message;
  }
  return _connectionMessage;
}

const _connectionMessage =
    'The account request failed. Check your connection and try again.';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key, required this.mode, this.returnPath});

  final AuthPageMode mode;
  final String? returnPath;

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _message;

  bool get _registering => widget.mode == AuthPageMode.register;

  @override
  void didUpdateWidget(AuthPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _error = null;
      _message = null;
      _password.clear();
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final repository = ref.read(authRepositoryProvider);
      final email = _email.text.trim();
      final result = _registering
          ? await repository.signUp(email: email, password: _password.text)
          : await repository.signIn(email: email, password: _password.text);
      if (result.session != null) {
        // Lets the browser offer to save the password. The router then moves
        // on, because the session has changed.
        TextInput.finishAutofillContext();
      } else if (mounted) {
        setState(() {
          if (_registering) {
            _message =
                'Check your email to confirm your account, then sign in.';
          } else {
            _error = 'Sign in did not complete. Try again.';
          }
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) {
        _password.clear();
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() {
        _error = 'Enter your email address above first.';
        _message = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordReset(
            email,
            redirectTo: passwordResetRedirect(ref.read(siteBaseUriProvider)),
          );
      if (mounted) {
        setState(
          () => _message =
              'If this email is registered, a password reset link has been '
              'sent. Open it in this browser.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final switchPath = _registering ? loginPath : registerPath;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 64),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: NorveColors.white,
                    border: Border.all(color: NorveColors.line),
                  ),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _registering
                                ? 'Create your account'
                                : 'Sign in to your account',
                            style: textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Save your favourites and keep your NORVÉ details '
                            'close.',
                            style: textTheme.bodySmall?.copyWith(
                              color: NorveColors.muted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 22),
                          TextFormField(
                            key: const ValueKey('auth-email'),
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                _emailPattern.hasMatch(value?.trim() ?? '')
                                ? null
                                : 'Enter a valid email address.',
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const ValueKey('auth-password'),
                            controller: _password,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: _registering
                                ? const [AutofillHints.newPassword]
                                : const [AutofillHints.password],
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null || value.length < 8
                                ? 'Use at least 8 characters.'
                                : null,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              key: const ValueKey('auth-error'),
                              style: textTheme.bodySmall,
                            ),
                          ],
                          if (_message != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _message!,
                              key: const ValueKey('auth-message'),
                              style: textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            key: const ValueKey('auth-submit'),
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: NorveColors.charcoal,
                              foregroundColor: NorveColors.white,
                              minimumSize: const Size.fromHeight(48),
                              shape: const RoundedRectangleBorder(),
                            ),
                            child: _busy
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: NorveColors.white,
                                    ),
                                  )
                                : Text(
                                    _registering ? 'Create Account' : 'Sign In',
                                  ),
                          ),
                          if (!_registering)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                key: const ValueKey('auth-forgot-password'),
                                onPressed: _busy ? null : _sendPasswordReset,
                                child: const Text('Forgot password?'),
                              ),
                            ),
                          const Divider(height: 28),
                          TextButton(
                            key: const ValueKey('auth-switch-mode'),
                            onPressed: _busy
                                ? null
                                : () => context.go(
                                    authLocation(switchPath, widget.returnPath),
                                  ),
                            child: Text(
                              _registering
                                  ? 'Already have an account? Sign in'
                                  : 'New to NORVÉ? Create an account',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const StorefrontFooterSliver(),
      ],
    );
  }
}
