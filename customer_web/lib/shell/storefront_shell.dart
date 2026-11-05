import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/theme/norve_theme.dart';

import '../app/breakpoints.dart';
import 'storefront_header.dart';

class StorefrontShell extends StatelessWidget {
  const StorefrontShell({
    super.key,
    required this.currentUri,
    required this.child,
  });

  final Uri currentUri;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: StorefrontBreakpoints.isDesktop(MediaQuery.sizeOf(context).width)
        ? null
        : const _StorefrontDrawer(),
    body: Column(
      children: [
        StorefrontHeader(currentUri: currentUri),
        const Divider(),
        // A route blocks accessibility for anything painted before it in the
        // same semantics container. Its own container keeps the header visible
        // to screen readers.
        Expanded(child: Semantics(container: true, child: child)),
      ],
    ),
  );
}

class _StorefrontDrawer extends StatelessWidget {
  const _StorefrontDrawer();

  @override
  Widget build(BuildContext context) => Drawer(
    key: const ValueKey('storefront-drawer'),
    backgroundColor: NorveColors.ivory,
    shape: const RoundedRectangleBorder(),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Text(
              'NORVÉ',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 24,
                letterSpacing: 5.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Divider(),
          for (final link in storefrontLinks)
            ListTile(
              leading: Icon(link.icon, size: 20),
              title: Text(link.label),
              onTap: () {
                Navigator.of(context).pop();
                context.go(link.route);
              },
            ),
        ],
      ),
    ),
  );
}
