import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/features/products/product.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Matches the columns ProductRepository.fetchProducts maps into Product.
const _productSelect =
    'id,sku,name,description,price_inr,original_price_inr,image_url,is_active,requires_size,requires_color,created_at,category_id,categories(id,name),product_images(image_url,storage_path,sort_order,is_primary),product_variants(id,sku,size,color_name,color_hex,price_override_inr,stock_quantity,is_available)';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Reads the shared Supabase catalogue for pages the web needs to open
/// directly. Row-level security decides what customers can see.
class StorefrontCatalogRepository {
  const StorefrontCatalogRepository(this._client);

  final SupabaseClient? _client;

  /// Returns null when the product doesn't exist or isn't visible.
  Future<Product?> fetchById(String id) async {
    final client = _client;
    if (client == null) {
      throw StateError('The storefront requires a Supabase client.');
    }
    if (!_uuid.hasMatch(id)) return null;
    final row = await client
        .from('products')
        .select(_productSelect)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Product.fromSupabaseRow(row);
  }
}

final storefrontCatalogRepositoryProvider =
    Provider<StorefrontCatalogRepository>(
      (ref) => StorefrontCatalogRepository(ref.watch(supabaseClientProvider)),
    );

/// Fetched each time a product page opens, so stock and price are current.
final storefrontProductProvider = FutureProvider.autoDispose
    .family<Product?, String>(
      (ref, id) => ref.watch(storefrontCatalogRepositoryProvider).fetchById(id),
    );
