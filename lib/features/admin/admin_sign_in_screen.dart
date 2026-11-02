import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/norve_theme.dart';

class AdminSignInScreen extends ConsumerStatefulWidget {
  const AdminSignInScreen({
    super.key,
    this.customerReturnLocation = '/account',
    this.showBackButton = true,
  });

  final String? customerReturnLocation;
  final bool showBackButton;

  @override
  ConsumerState<AdminSignInScreen> createState() => _AdminSignInScreenState();
}

class _AdminSignInScreenState extends ConsumerState<AdminSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(supabaseConfigProvider);
    final startupError = ref.watch(supabaseStartupErrorProvider);
    final client = ref.watch(supabaseClientProvider);
    final adminAccess = ref.watch(adminAccessProvider);
    final authorized = adminAccess.asData?.value == true;
    final accessError = adminAccess.asError?.error;
    final hasCustomerSession =
        client?.auth.currentUser != null && adminAccess.asData?.value == false;
    final unavailableMessage = startupError ?? config.configurationMessage;
    final canSignIn =
        client != null && startupError == null && config.isConfigured;

    return Scaffold(
      appBar: AppBar(
        leading: widget.showBackButton
            ? IconButton(
                tooltip: 'Back to account',
                onPressed: () => context.go(
                  widget.customerReturnLocation ?? '/admin/sign-in',
                ),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Text(
          'NORVÉ',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(letterSpacing: 3.2),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: NorveColors.white,
                  border: Border.all(color: NorveColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Admin Sign In',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Administrator access is verified by the database. There is no public admin registration.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: NorveColors.muted, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    if (authorized)
                      FilledButton(
                        onPressed: () => context.go('/admin'),
                        child: const Text('Open Admin Dashboard'),
                      )
                    else if (accessError != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Administrator access could not be verified. Check the connection and try again.',
                            key: const ValueKey('admin-verification-error'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(height: 1.5),
                          ),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(adminAccessProvider),
                            child: const Text('Retry verification'),
                          ),
                        ],
                      )
                    else if (!canSignIn)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: NorveColors.ivory,
                          border: Border.all(color: NorveColors.line),
                        ),
                        child: Text(
                          unavailableMessage,
                          key: const ValueKey('admin-auth-configuration-state'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(height: 1.5),
                        ),
                      )
                    else
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (hasCustomerSession) ...[
                              Text(
                                widget.customerReturnLocation == null
                                    ? 'The signed-in account does not have administrator access. Sign out and use an authorized administrator account.'
                                    : 'The signed-in account does not have administrator access. You can return to your customer account or sign in with an authorized administrator account.',
                                key: const ValueKey(
                                  'admin-unauthorized-session',
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(height: 1.5),
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              key: const ValueKey('admin-email'),
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value == null || !value.contains('@')
                                  ? 'Enter a valid email address.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const ValueKey('admin-password'),
                              controller: _password,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Enter your password.'
                                  : null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                key: const ValueKey('admin-auth-error'),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: NorveColors.charcoal),
                              ),
                            ],
                            const SizedBox(height: 18),
                            FilledButton(
                              key: const ValueKey('admin-sign-in-submit'),
                              onPressed: _busy ? null : _signIn,
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
                                      ),
                                    )
                                  : const Text('Sign In'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!await isVerifiedAdministrator(client, response.user)) {
        await client.auth.signOut();
        throw const _NotAdministratorException();
      }
      if (mounted) context.go('/admin');
    } on _NotAdministratorException {
      if (mounted) {
        setState(
          () => _error =
              'This account is not authorized to manage the catalogue.',
        );
      }
    } on PostgrestException {
      if (mounted) {
        setState(
          () => _error = 'Administrator access could not be verified. Check the database connection and try again.',
        );
      }
    } on AuthException {
      if (mounted) {
        setState(
          () =>
              _error = 'Sign in failed. Check your credentials and try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'The sign-in request failed. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _NotAdministratorException implements Exception {
  const _NotAdministratorException();
}
