import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shell/storefront_header.dart';
import '../widgets/storefront_state_view.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('storefront-not-found'),
    body: Column(
      children: [
        const StorefrontHeader(showMenu: false),
        const Divider(),
        Expanded(
          child: SingleChildScrollView(
            child: StorefrontMessageView(
              title: 'This page could not be found',
              message: 'The link may be out of date, or the page may have moved.',
              actionLabel: 'Continue Shopping',
              onAction: () => context.go('/shop'),
            ),
          ),
        ),
      ],
    ),
  );
}
