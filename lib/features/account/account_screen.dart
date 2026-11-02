import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/norve_theme.dart';
import 'customer_addresses_section.dart';
import 'customer_profile_section.dart';

enum _CustomerAuthMode { signIn, signUp }

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _signingOut = false;
  String? _signOutError;

  @override
  Widget build(BuildContext context) {
    final startupError = ref.watch(supabaseStartupErrorProvider);
    final canAuthenticate = ref.watch(authServicesAvailableProvider);
    final sessionState = ref.watch(authSessionProvider);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width >= 1024
                  ? 760
                  : MediaQuery.sizeOf(context).width >= 768
                  ? 680
                  : 460,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(
                    'NORVÉ',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(letterSpacing: 4),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Account',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 14),
                sessionState.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => _InfoCard(
                    message: 'Your account status could not be loaded. Check your connection and try again.',
                    onRetry: () => ref.invalidate(authSessionProvider),
                  ),
                  data: (session) => session == null
                      ? canAuthenticate
                            ? const _CustomerAuthPanel()
                            : _InfoCard(
                                message: startupError == null
                                    ? 'Account services are unavailable right now.'
                                    : 'Account services could not start. Try again later.',
                              )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SignedInPanel(
                              signingOut: _signingOut,
                              error: _signOutError,
                              onSignOut: _signOut,
                              onViewOrders: () => context.go('/account/orders'),
                            ),
                            const SizedBox(height: 14),
                            CustomerProfileSection(
                              key: ValueKey('profile-${session.userId}'),
                              userId: session.userId,
                              email: session.email ?? '',
                            ),
                            const SizedBox(height: 14),
                            CustomerAddressesSection(
                              key: ValueKey('addresses-${session.userId}'),
                              userId: session.userId,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    setState(() {
      _signingOut = true;
      _signOutError = null;
    });
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on AuthException catch (error) {
      if (mounted) setState(() => _signOutError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _signOutError =
              'Sign out failed. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }
}

class _CustomerAuthPanel extends ConsumerStatefulWidget {
  const _CustomerAuthPanel();

  @override
  ConsumerState<_CustomerAuthPanel> createState() => _CustomerAuthPanelState();
}

class _CustomerAuthPanelState extends ConsumerState<_CustomerAuthPanel> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  _CustomerAuthMode _mode = _CustomerAuthMode.signIn;
  bool _busy = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signingUp = _mode == _CustomerAuthMode.signUp;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: NorveColors.white,
        border: Border.all(color: NorveColors.line),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              signingUp ? 'Create your account' : 'Sign in to your account',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            Text(
              'Save your favourites and keep your NORVÉ details close.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: NorveColors.muted, height: 1.5),
            ),
            const SizedBox(height: 19),
            SegmentedButton<_CustomerAuthMode>(
              segments: const [
                ButtonSegment(
                  value: _CustomerAuthMode.signIn,
                  label: Text('Sign In'),
                ),
                ButtonSegment(
                  value: _CustomerAuthMode.signUp,
                  label: Text('Create Account'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _busy
                  ? null
                  : (selection) => setState(() {
                      _mode = selection.first;
                      _message = null;
                      _error = null;
                    }),
            ),
            const SizedBox(height: 18),
            TextFormField(
              key: const ValueKey('customer-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null ||
                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(value.trim())
                  ? 'Enter a valid email address.'
                  : null,
            ),
            const SizedBox(height: 13),
            TextFormField(
              key: const ValueKey('customer-password'),
              controller: _password,
              obscureText: true,
              autofillHints: signingUp
                  ? const [AutofillHints.newPassword]
                  : const [AutofillHints.password],
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.length < 8
                  ? 'Use at least 8 characters.'
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const ValueKey('customer-auth-error'),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: NorveColors.charcoal),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                key: const ValueKey('customer-auth-message'),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: NorveColors.charcoal),
              ),
            ],
            const SizedBox(height: 17),
            FilledButton(
              key: const ValueKey('customer-auth-submit'),
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(signingUp ? 'Create Account' : 'Sign In'),
            ),
            if (!signingUp)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('customer-password-reset'),
                  onPressed: _busy ? null : _sendPasswordReset,
                  child: const Text('Forgot password?'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final repository = ref.read(authRepositoryProvider);
      if (_mode == _CustomerAuthMode.signUp) {
        final result = await repository.signUp(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (result.session == null) {
          setState(
            () => _error = 'Registration did not start an authenticated session. Check Supabase email confirmation settings and try again.',
          );
        }
      } else {
        final result = await repository.signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (result.session == null) {
          setState(
            () => _error =
                'Sign in did not return an authenticated session. Try again.',
          );
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = _authError(error));
    } finally {
      if (mounted) {
        _password.clear();
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
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
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      setState(
        () => _message =
            'If this email is registered, a password reset link has been sent.',
      );
    } catch (error) {
      if (mounted) setState(() => _error = _authError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _authError(Object error) {
    if (error is AuthRepositoryException) return error.message;
    if (error is AuthException) return error.message;
    return 'The account request failed. Check your connection and try again.';
  }
}

class _SignedInPanel extends StatelessWidget {
  const _SignedInPanel({
    required this.signingOut,
    required this.onSignOut,
    required this.onViewOrders,
    this.error,
  });

  final bool signingOut;
  final String? error;
  final VoidCallback onSignOut;
  final VoidCallback onViewOrders;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: NorveColors.white,
      border: Border.all(color: NorveColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome back', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 17),
        OutlinedButton(
          key: const ValueKey('customer-order-history'),
          onPressed: onViewOrders,
          child: const Text('Your Orders'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey('customer-sign-out'),
          onPressed: signingOut ? null : onSignOut,
          child: signingOut
              ? const CircularProgressIndicator()
              : const Text('Sign Out'),
        ),
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: NorveColors.white,
      border: Border.all(color: NorveColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
