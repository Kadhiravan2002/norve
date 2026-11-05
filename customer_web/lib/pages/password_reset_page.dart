import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/auth/auth_providers.dart';
import 'package:norve/features/account/password_reset_screen.dart';

import '../app/route_guards.dart';
import '../shell/storefront_header.dart';
import '../widgets/storefront_state_view.dart';

/// Shows mobile's new-password screen when a reset link has signed the customer
/// in. Startup has already tried the link, so no session means it did not work.
class PasswordResetPage extends ConsumerWidget {
  const PasswordResetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authSessionProvider);
    if (ref.read(authRepositoryProvider).currentSession != null) {
      return const PasswordResetScreen();
    }
    return Scaffold(
      body: Column(
        children: [
          const StorefrontHeader(showMenu: false),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: StorefrontMessageView(
                key: const ValueKey('password-reset-link-invalid'),
                icon: Icons.link_off_outlined,
                title: 'This reset link is not valid',
                message:
                    'It may have expired, been used already, or been opened in '
                    'a different browser. Request a new link from the sign-in '
                    'page and open it in the same browser.',
                actionLabel: 'Go to Sign In',
                onAction: () => context.go(loginPath),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
