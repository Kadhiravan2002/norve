import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/application_role_provider.dart';
import '../../core/supabase/supabase_providers.dart';
import 'widgets/admin_widgets.dart';

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
  bool _obscurePassword = true;
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
    final role = ref.watch(applicationRoleProvider).asData?.value;
    final adminAccess = ref.watch(adminAccessProvider);
    final authorized = role == ApplicationRole.administrator;
    final accessError = adminAccess.asError?.error;
    final hasCustomerSession = !_busy &&
        !adminAccess.isLoading &&
        (role == ApplicationRole.customer ||
            (client?.auth.currentUser != null &&
                adminAccess.asData?.value == false));
    final unavailableMessage = startupError ?? config.configurationMessage;
    final canSignIn =
        client != null && startupError == null && config.isConfigured;

    ref.listen<AsyncValue<ApplicationRole>>(applicationRoleProvider, (previous, next) {
      if (!_busy && next.asData?.value == ApplicationRole.administrator) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/admin');
        });
      }
    });

    if (authorized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/admin');
      });
      return const Scaffold(
        backgroundColor: AdminColors.ivory,
        body: Center(
          child: CircularProgressIndicator(color: AdminColors.charcoal),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AdminColors.ivory,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hidden identifier for semantic/test accessibility
                  const SizedBox.shrink(
                    child: Text(
                      'Admin Sign In',
                      style: TextStyle(fontSize: 0),
                    ),
                  ),

                  // Optional back button when showBackButton is enabled
                  if (widget.showBackButton) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: IconButton(
                          tooltip: 'Back to account',
                          onPressed: () => context.go(
                            widget.customerReturnLocation ?? '/admin/sign-in',
                          ),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AdminColors.charcoal,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Centered Card matching reference image
                  Container(
                    decoration: BoxDecoration(
                      color: AdminColors.white,
                      border: Border.all(
                        color: const Color(0xFFE8E2D9),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A24211E),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 36,
                      vertical: 40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Brand Header: "— NORVÉ —"
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 38,
                              height: 1,
                              color: const Color(0xFFD6CFC4),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'NORVÉ',
                              style: TextStyle(
                                fontFamily: 'PlayfairDisplay',
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 5.0,
                                color: AdminColors.charcoal,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              width: 38,
                              height: 1,
                              color: const Color(0xFFD6CFC4),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Subheading: "Management Console" in italic serif
                        const Center(
                          child: Text(
                            'Management Console',
                            style: TextStyle(
                              fontFamily: 'PlayfairDisplay',
                              fontSize: 19,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                              color: AdminColors.charcoal,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Supporting text
                        const Center(
                          child: Text(
                            'Access the store operations, catalogue, orders, and collections.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                              height: 1.45,
                              color: Color(0xFF77716A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Error & State Notices
                        if (accessError != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AdminColors.errorBg,
                              border: Border.all(color: AdminColors.errorBorder),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Administrator access could not be verified. Check the connection and try again.',
                                  key: const ValueKey('admin-verification-error'),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: AdminColors.error,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextButton(
                                  onPressed: () =>
                                      ref.invalidate(adminAccessProvider),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: AdminColors.error,
                                  ),
                                  child: const Text(
                                    'Retry verification',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ] else if (!canSignIn) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AdminColors.surfaceSubtle,
                              border: Border.all(color: AdminColors.line),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              unavailableMessage,
                              key: const ValueKey('admin-auth-configuration-state'),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: AdminColors.muted,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ] else ...[
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (hasCustomerSession) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: AdminColors.warningBg,
                                      border: Border.all(
                                        color: AdminColors.warningBorder,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      widget.customerReturnLocation == null
                                          ? 'The signed-in account does not have administrator access. Sign out and use an authorized administrator account.'
                                          : 'The signed-in account does not have administrator access. You can return to your customer account or sign in with an authorized administrator account.',
                                      key: const ValueKey(
                                        'admin-unauthorized-session',
                                      ),
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: AdminColors.warning,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],

                                // Email Field
                                const Text(
                                  'Email',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AdminColors.charcoal,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  key: const ValueKey('admin-email'),
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  autocorrect: false,
                                  cursorColor: AdminColors.charcoal,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: AdminColors.charcoal,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter your email',
                                    hintStyle: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      color: Color(0xFF9E978E),
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.mail_outline,
                                      size: 18,
                                      color: Color(0xFF77716A),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 42,
                                      minHeight: 42,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFFAF8F5),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2DDD5),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2DDD5),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: AdminColors.charcoal,
                                        width: 1.2,
                                      ),
                                    ),
                                  ),
                                  validator: (value) =>
                                      value == null || !value.contains('@')
                                          ? 'Enter a valid email address.'
                                          : null,
                                ),
                                const SizedBox(height: 18),

                                // Password Field
                                const Text(
                                  'Password',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AdminColors.charcoal,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  key: const ValueKey('admin-password'),
                                  controller: _password,
                                  obscureText: _obscurePassword,
                                  cursorColor: AdminColors.charcoal,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: AdminColors.charcoal,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter your password',
                                    hintStyle: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      color: Color(0xFF9E978E),
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.lock_outline,
                                      size: 18,
                                      color: Color(0xFF77716A),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 42,
                                      minHeight: 42,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 18,
                                        color: const Color(0xFF77716A),
                                      ),
                                      tooltip: _obscurePassword
                                          ? 'Show password'
                                          : 'Hide password',
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFFAF8F5),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2DDD5),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2DDD5),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: AdminColors.charcoal,
                                        width: 1.2,
                                      ),
                                    ),
                                  ),
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                          ? 'Enter your password.'
                                          : null,
                                ),

                                if (_error != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(top: 14),
                                    decoration: BoxDecoration(
                                      color: AdminColors.errorBg,
                                      border: Border.all(
                                        color: AdminColors.errorBorder,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _error!,
                                      key: const ValueKey('admin-auth-error'),
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: AdminColors.error,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 26),

                                // Primary Action: "Continue"
                                AdminButton(
                                  key: const ValueKey('admin-sign-in-submit'),
                                  label: 'Continue',
                                  isFullWidth: true,
                                  size: AdminButtonSize.lg,
                                  isLoading: _busy,
                                  onPressed: _busy ? null : _signIn,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
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
      final isAdmin = await ref
          .read(adminAccessProvider.notifier)
          .verifyUser(client, response.user);
      if (!isAdmin) {
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
          () => _error =
              'Administrator access could not be verified. Check the database connection and try again.',
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
          () => _error =
              'The sign-in request failed. Check your connection and try again.',
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
