import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/auth/auth_providers.dart';
import 'package:norve/core/auth/auth_repository.dart';
import 'package:norve/core/supabase/supabase_config.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve/features/products/product_repository.dart';
import 'package:norve_customer_web/app/router.dart';
import 'package:norve_customer_web/app/storefront_app.dart';
import 'package:norve_customer_web/catalog/storefront_catalog_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const testProductId = '11111111-1111-4111-8111-111111111111';

/// Test-only data. An empty image URL resolves to the fallback with no request.
Product testProduct({
  String id = testProductId,
  String name = 'Live Linen Shirt',
  int price = 2499,
  int? originalPrice,
  String categoryId = 'cat-tops',
  String category = 'Tops',
  String description = 'From Supabase.',
  DateTime? createdAt,
  List<ProductVariant> variants = const [],
  List<String> sizes = const [],
  List<ProductColor> colors = const [],
  List<String> gallery = const [],
  bool requiresSize = false,
  bool requiresColor = false,
  int stock = 20,
}) => Product(
  id: id,
  name: name,
  price: price,
  originalPrice: originalPrice,
  imageUrl: '',
  category: category,
  categoryId: categoryId,
  description: description,
  createdAt: createdAt,
  variants: variants,
  sizes: sizes,
  colors: colors,
  galleryImageUrls: gallery,
  requiresSize: requiresSize,
  requiresColor: requiresColor,
  stockQuantity: stock,
);

ProductVariant testVariant(
  String size,
  String color, {
  int stock = 5,
  int? price,
}) => ProductVariant(
  id: '$size-$color',
  size: size,
  colorName: color,
  colorValue: 0xFF24211E,
  stockQuantity: stock,
  priceOverride: price,
);

const testCategories = [
  ProductCategory(id: 'cat-tops', name: 'Tops', slug: 'tops'),
  ProductCategory(id: 'cat-outer', name: 'Outerwear', slug: 'outerwear'),
];

class FakeProductRepository extends ProductRepository {
  FakeProductRepository(this.fetch, this.categories) : super(null);

  final Future<List<Product>> Function() fetch;
  final Future<List<ProductCategory>> Function() categories;

  @override
  Future<List<Product>> fetchProducts() => fetch();

  @override
  Future<List<ProductCategory>> fetchCategories() => categories();
}

class FakeCatalogRepository extends StorefrontCatalogRepository {
  const FakeCatalogRepository(this.product) : super(null);

  final Product? product;

  @override
  Future<Product?> fetchById(String id) async => product;
}

class GuestAuthRepository implements AuthRepository {
  @override
  AuthSession? get currentSession => null;
  @override
  Stream<AuthSession?> watchSession() => Stream.value(null);
  @override
  Stream<AuthChangeEvent?> watchAuthEvents() => const Stream.empty();
  @override
  Future<AuthActionResult> signIn({
    required String email,
    required String password,
  }) => throw UnimplementedError();
  @override
  Future<AuthActionResult> signUp({
    required String email,
    required String password,
  }) => throw UnimplementedError();
  @override
  Future<void> signOut() async {}
  @override
  Future<void> sendPasswordReset(String email, {String? redirectTo}) async {}
  @override
  Future<void> updatePassword(String password) async {}
}

Future<ProviderContainer> pumpStorefront(
  WidgetTester tester, {
  required Future<List<Product>> Function() catalogue,
  Future<List<ProductCategory>> Function()? categories,
  Product? directProduct,
  String location = '/',
  Size size = const Size(1280, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      supabaseConfigProvider.overrideWithValue(
        const SupabaseConfig(
          url: 'https://example.supabase.co',
          publishableKey: 'sb_publishable_test',
        ),
      ),
      supabaseClientProvider.overrideWithValue(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      ),
      authRepositoryProvider.overrideWithValue(GuestAuthRepository()),
      productRepositoryProvider.overrideWithValue(
        FakeProductRepository(
          catalogue,
          categories ?? () async => testCategories,
        ),
      ),
      storefrontCatalogRepositoryProvider.overrideWithValue(
        FakeCatalogRepository(directProduct),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(storefrontRouterProvider).go(location);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const StorefrontApp(),
    ),
  );
  return container;
}

/// Lets async providers settle without waiting on endless spinners.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

GoRouter routerOf(ProviderContainer container) =>
    container.read(storefrontRouterProvider);

Uri currentUri(ProviderContainer container) =>
    routerOf(container).routeInformationProvider.value.uri;
