import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/theme/norve_theme.dart';

class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back to account',
        onPressed: () => context.go('/account'),
        icon: const Icon(Icons.arrow_back),
      ),
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
              padding: const EdgeInsets.all(24),
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
                      'Choose a new password',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter a new password for your account.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: NorveColors.muted, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const ValueKey('new-password'),
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.length < 8
                          ? 'Use at least 8 characters.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const ValueKey('confirm-new-password'),
                      controller: _confirmation,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value != _password.text
                          ? 'Passwords do not match.'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        key: const ValueKey('password-reset-error'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      key: const ValueKey('save-new-password'),
                      onPressed: _busy ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: NorveColors.charcoal,
                        foregroundColor: NorveColors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: const RoundedRectangleBorder(),
                      ),
                      child: _busy
                          ? const CircularProgressIndicator()
                          : const Text('Save New Password'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your password has been updated.')),
        );
        context.go('/account');
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on AuthRepositoryException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'The password could not be updated. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
