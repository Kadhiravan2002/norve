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

Stream<bool> _administratorStream(SupabaseClient client) =>
    Stream<bool>.multi((sink) {
      var revision = 0;
      void verify(User? user, int requestRevision) {
        isVerifiedAdministrator(client, user).then((isAdmin) {
          if (requestRevision == revision) sink.add(isAdmin);
        }, onError: sink.addError);
      }

      final subscription = client.auth.onAuthStateChange.listen((event) {
        final eventRevision = ++revision;
        verify(event.session?.user, eventRevision);
      }, onError: sink.addError);
      verify(client.auth.currentUser, revision);
      sink.onCancel = subscription.cancel;
    });

final adminAccessProvider = StreamProvider<bool>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return Stream<bool>.value(false);
  return _administratorStream(client);
});

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
