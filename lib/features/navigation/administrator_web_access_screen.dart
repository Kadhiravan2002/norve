import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/application_role_provider.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/norve_theme.dart';

const _adminWebUrl = String.fromEnvironment('NORVE_ADMIN_WEB_URL');

class AdministratorWebAccessScreen extends ConsumerWidget {
  const AdministratorWebAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(applicationRoleProvider)
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, stackTrace) => const Scaffold(
          body: Center(
            child: Text('Administrator access could not be verified.'),
          ),
        ),
        data: (role) {
          if (role != ApplicationRole.administrator) {
            return const _AccessRedirect('/account');
          }
          final adminUri = Uri.tryParse(_adminWebUrl);
          final hasAdminUrl =
              adminUri != null &&
              adminUri.scheme == 'https' &&
              adminUri.host.isNotEmpty;

          return Scaffold(
            appBar: AppBar(
              title: Text(
                'NORVÉ',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(letterSpacing: 3.2),
              ),
              actions: [
                TextButton.icon(
                  key: const ValueKey('administrator-sign-out'),
                  onPressed: () => _signOut(context, ref),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: NorveColors.white,
                        border: Border.all(color: NorveColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Administration',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            hasAdminUrl
                                ? 'Administrator access is managed in the standalone NORVÉ Admin Web application.'
                                : 'The standalone NORVÉ Admin Web URL has not been configured for this app. Use your organization’s published admin URL to continue.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(height: 1.55),
                          ),
                          if (hasAdminUrl) ...[
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                key: const ValueKey('open-admin-web'),
                                onPressed: () => _openAdmin(context, adminUri),
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Open Admin Web'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

  Future<void> _openAdmin(BuildContext context, Uri? uri) async {
    if (uri == null) return;
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        _showMessage(context, 'The admin dashboard could not be opened.');
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'The admin dashboard could not be opened.');
      }
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;
    try {
      await client.auth.signOut();
      if (context.mounted) context.go('/account');
    } on AuthException catch (error) {
      if (context.mounted) {
        _showMessage(context, 'Sign out failed. ${error.message}');
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(
          context,
          'Sign out failed. Check your connection and try again.',
        );
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AccessRedirect extends StatefulWidget {
  const _AccessRedirect(this.location);

  final String location;

  @override
  State<_AccessRedirect> createState() => _AccessRedirectState();
}

class _AccessRedirectState extends State<_AccessRedirect> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GoRouter.of(context).go(widget.location);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
