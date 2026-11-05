import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/breakpoints.dart';

/// Adds a visible way back to a reused mobile screen, which has none of its own
/// and fills its space with its own scrolling.
class BackLinkFrame extends StatelessWidget {
  const BackLinkFrame({
    super.key,
    required this.label,
    required this.route,
    required this.child,
  });

  final String label;
  final String route;
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: StorefrontBreakpoints.contentMaxWidth,
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: TextButton.icon(
                key: const ValueKey('back-link'),
                onPressed: () => context.go(route),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(label),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    ),
  );
}
