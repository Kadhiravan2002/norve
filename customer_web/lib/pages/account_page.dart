import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/auth/auth_providers.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/account/customer_addresses_section.dart';
import 'package:norve/features/account/customer_profile_section.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../app/breakpoints.dart';
import '../shell/storefront_footer.dart';
import '../widgets/storefront_state_view.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  bool _signingOut = false;
  String? _signOutError;

  Future<void> _signOut() async {
    setState(() {
      _signingOut = true;
      _signOutError = null;
    });
    try {
      // The router moves to sign-in once the session has ended.
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

  @override
  Widget build(BuildContext context) {
    // Rebuilds on session changes, but reads the session the router trusts, so
    // a passing stream error cannot strand a signed-in customer on this page.
    ref.watch(authSessionProvider);
    final session = ref.read(authRepositoryProvider).currentSession;
    if (session == null) {
      return const SingleChildScrollView(child: StorefrontLoadingView());
    }

    final width = MediaQuery.sizeOf(context).width;
    final gutter = StorefrontBreakpoints.gutter(width);
    final summary = _AccountSummary(
      email: session.email ?? '',
      signingOut: _signingOut,
      error: _signOutError,
      onSignOut: _signOut,
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomerProfileSection(
          key: ValueKey('profile-${session.userId}'),
          userId: session.userId,
          email: session.email ?? '',
        ),
        const SizedBox(height: 16),
        CustomerAddressesSection(
          key: ValueKey('addresses-${session.userId}'),
          userId: session.userId,
        ),
      ],
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Padding(
                padding: EdgeInsets.fromLTRB(gutter, 36, gutter, 64),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Account',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    if (StorefrontBreakpoints.isDesktop(width))
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 300, child: summary),
                          const SizedBox(width: 24),
                          Expanded(child: details),
                        ],
                      )
                    else ...[
                      summary,
                      const SizedBox(height: 16),
                      details,
                    ],
                  ],
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

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({
    required this.email,
    required this.signingOut,
    required this.onSignOut,
    this.error,
  });

  final String email;
  final bool signingOut;
  final String? error;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NorveColors.white,
        border: Border.all(color: NorveColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Welcome back', style: textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            email,
            style: textTheme.bodySmall?.copyWith(color: NorveColors.muted),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              key: const ValueKey('sign-out-error'),
              style: textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 18),
          OutlinedButton(
            key: const ValueKey('account-orders'),
            onPressed: () => context.go('/account/orders'),
            child: const Text('Your Orders'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('account-sign-out'),
            onPressed: signingOut ? null : onSignOut,
            child: signingOut
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
