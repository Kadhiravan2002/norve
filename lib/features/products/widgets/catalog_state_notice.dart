import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/norve_theme.dart';
import '../product_catalog_provider.dart';

class CatalogStateNotice extends ConsumerWidget {
  const CatalogStateNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(catalogLoadStateProvider);
    if (status.phase == CatalogPhase.live) return const SizedBox.shrink();
    final content = switch (status.phase) {
      CatalogPhase.development =>
        'Development catalogue · not live inventory or business data.',
      CatalogPhase.loading => 'Loading the catalogue from Supabase…',
      CatalogPhase.saving => 'Saving catalogue changes…',
      CatalogPhase.error =>
        status.message ?? 'Catalogue connection is unavailable.',
      CatalogPhase.live => '',
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: NorveColors.white,
        border: Border.all(color: NorveColors.line),
      ),
      child: Row(
        children: [
          if (status.phase == CatalogPhase.loading ||
              status.phase == CatalogPhase.saving)
            const SizedBox.square(
              dimension: 15,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: NorveColors.charcoal,
              ),
            )
          else
            const Icon(Icons.info_outline, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              content,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(height: 1.35),
            ),
          ),
          if (status.phase == CatalogPhase.error)
            TextButton(
              onPressed: () =>
                  ref.read(productCatalogProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}
