import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_providers.dart';
import 'product.dart';

enum CatalogPhase { development, loading, live, error, saving }

class CatalogLoadState {
  const CatalogLoadState(this.phase, {this.message});

  final CatalogPhase phase;
  final String? message;

  bool get hasError => phase == CatalogPhase.error;
}

class CatalogLoadController extends Notifier<CatalogLoadState> {
  @override
  CatalogLoadState build() {
    final client = ref.watch(supabaseClientProvider);
    final startupError = ref.watch(supabaseStartupErrorProvider);
    if (startupError != null) {
      return CatalogLoadState(CatalogPhase.error, message: startupError);
    }
    return CatalogLoadState(
      client == null ? CatalogPhase.development : CatalogPhase.loading,
    );
  }

  void set(CatalogLoadState value) => state = value;
}

final catalogLoadStateProvider =
    NotifierProvider<CatalogLoadController, CatalogLoadState>(
      CatalogLoadController.new,
    );

/// The customer and admin surfaces share this provider. When Supabase is
/// configured, the local fixture is replaced only after a successful fetch.
class ProductCatalogController extends Notifier<List<Product>> {
  @override
  List<Product> build() {
    final client = ref.watch(supabaseClientProvider);
    final startupError = ref.watch(supabaseStartupErrorProvider);
    ref.listen(adminAccessProvider, (previous, next) {
      final wasAdmin = previous?.asData?.value;
      final isAdmin = next.asData?.value;
      if (wasAdmin != null && isAdmin != null && wasAdmin != isAdmin) {
        Future.microtask(refresh);
      }
    });
    if (client == null) {
      if (startupError != null) return const [];
      return products;
    }
    Future.microtask(refresh);
    return const [];
  }

  Future<void> refresh() async {
    ref
        .read(catalogLoadStateProvider.notifier)
        .set(const CatalogLoadState(CatalogPhase.loading));
    try {
      final next = await ref.read(productRepositoryProvider).fetchProducts();
      state = next;
      ref
          .read(catalogLoadStateProvider.notifier)
          .set(const CatalogLoadState(CatalogPhase.live));
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Product catalogue request failed: $error');
      }
      ref
          .read(catalogLoadStateProvider.notifier)
          .set(
            CatalogLoadState(
              CatalogPhase.error,
              message: _friendlyError(error),
            ),
          );
    }
  }

  Future<void> save(Product product, {required bool create}) async {
    ref
        .read(catalogLoadStateProvider.notifier)
        .set(const CatalogLoadState(CatalogPhase.saving));
    try {
      final repository = ref.read(productRepositoryProvider);
      final saved = create
          ? await repository.create(product)
          : await repository.update(product);
      final index = state.indexWhere((item) => item.id == saved.id);
      if (index < 0) {
        state = [...state, saved];
      } else {
        final next = [...state];
        next[index] = saved;
        state = next;
      }
      ref.invalidate(productCategoriesProvider);
      ref
          .read(catalogLoadStateProvider.notifier)
          .set(const CatalogLoadState(CatalogPhase.live));
    } catch (error) {
      ref
          .read(catalogLoadStateProvider.notifier)
          .set(
            CatalogLoadState(
              CatalogPhase.error,
              message: _friendlyError(error),
            ),
          );
      rethrow;
    }
  }

  Future<void> delete(String productId) async {
    ref
        .read(catalogLoadStateProvider.notifier)
        .set(const CatalogLoadState(CatalogPhase.saving));
    try {
      await ref.read(productRepositoryProvider).delete(productId);
      state = state.where((product) => product.id != productId).toList();
      ref
          .read(catalogLoadStateProvider.notifier)
          .set(const CatalogLoadState(CatalogPhase.live));
    } catch (error) {
      ref
          .read(catalogLoadStateProvider.notifier)
          .set(
            CatalogLoadState(
              CatalogPhase.error,
              message: _friendlyError(error),
            ),
          );
      rethrow;
    }
  }

  String _friendlyError(Object error) {
    final details = error.toString().toLowerCase();
    if (details.contains('pgrst200') ||
        details.contains('pgrst205') ||
        details.contains('42703')) {
      return 'The catalogue database schema is out of date. Apply the latest catalogue migration, then retry.';
    }
    if (details.contains('jwt') ||
        details.contains('permission') ||
        details.contains('42501') ||
        details.contains('row-level security')) {
      return 'Administrator authorization was denied. Sign in with an authorized account.';
    }
    return 'Catalogue request failed. Check the connection and try again.';
  }
}

final productCatalogProvider =
    NotifierProvider<ProductCatalogController, List<Product>>(
      ProductCatalogController.new,
    );
