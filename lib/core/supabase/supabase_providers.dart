import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:async';

import '../../features/products/product_repository.dart';
import 'supabase_config.dart';

final supabaseConfigProvider = Provider<SupabaseConfig>(
  (ref) => SupabaseConfig.fromEnvironment(),
);

final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);

final supabaseStartupErrorProvider = Provider<String?>((ref) => null);

Future<bool> isVerifiedAdministrator(SupabaseClient client, User? user) async {
  if (user == null) return false;
  final row = await client
      .from('admin_users')
      .select('user_id')
      .eq('user_id', user.id)
      .maybeSingle();
  return row != null;
}

class AdminAccessNotifier extends AsyncNotifier<bool> {
  StreamSubscription<AuthState>? _authSubscription;
  int _revision = 0;
  String? _verifiedUserId;

  @override
  Future<bool> build() async {
    final client = ref.watch(supabaseClientProvider);
    if (client == null) return false;

    _authSubscription?.cancel();
    _authSubscription = client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user?.id != _verifiedUserId) {
        verifyUser(client, user);
      }
    });
    ref.onDispose(() => _authSubscription?.cancel());

    final currentUser = client.auth.currentUser;
    if (currentUser == null) {
      _verifiedUserId = null;
      return false;
    }
    _verifiedUserId = currentUser.id;
    return isVerifiedAdministrator(client, currentUser);
  }

  Future<bool> verifyUser(SupabaseClient client, User? user) async {
    final currentRevision = ++_revision;
    if (user == null) {
      _verifiedUserId = null;
      state = const AsyncData(false);
      return false;
    }

    state = const AsyncLoading();
    try {
      final isAdmin = await isVerifiedAdministrator(client, user);
      if (currentRevision == _revision) {
        _verifiedUserId = user.id;
        state = AsyncData(isAdmin);
      }
      return isAdmin;
    } catch (error, stackTrace) {
      if (currentRevision == _revision) {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    }
  }
}

final adminAccessProvider =
    AsyncNotifierProvider<AdminAccessNotifier, bool>(AdminAccessNotifier.new);

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(supabaseClientProvider));
});

final productCategoriesProvider = FutureProvider<List<ProductCategory>>((ref) {
  if (ref.watch(supabaseStartupErrorProvider) != null) {
    throw const ProductRepositoryException(
      'Supabase could not be initialized. Check configuration and connection.',
    );
  }
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return const <ProductCategory>[];
  }
  return ref.watch(productRepositoryProvider).fetchCategories();
});

String slugify(String value) => value
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');
