import 'package:norve/features/products/product.dart';

enum CatalogueSort {
  newest('newest', 'Newest'),
  priceLowToHigh('price-asc', 'Price: low to high'),
  priceHighToLow('price-desc', 'Price: high to low');

  const CatalogueSort(this.param, this.label);

  final String param;
  final String label;
}

enum CatalogueAvailability {
  any('any', 'Any availability'),
  inStock('in', 'In stock'),
  outOfStock('out', 'Out of stock');

  const CatalogueAvailability(this.param, this.label);

  final String param;
  final String label;
}

/// How many of the newest products the New Arrivals view shows.
const newArrivalsLimit = 12;

/// Newest first, matching the mobile app. Undated products go last, and ties
/// use the name so the order doesn't shift between loads.
int _newestFirst(Product a, Product b) {
  final aDate = a.createdAt;
  final bDate = b.createdAt;
  if (aDate == null && bDate != null) return 1;
  if (aDate != null && bDate == null) return -1;
  if (aDate != null && bDate != null) {
    final byDate = bDate.compareTo(aDate);
    if (byDate != 0) return byDate;
  }
  return a.name.compareTo(b.name);
}

List<Product> newestProducts(Iterable<Product> products) =>
    products.where((product) => product.isActive).toList()..sort(_newestFirst);

List<Product> newArrivals(Iterable<Product> products) =>
    newestProducts(products).take(newArrivalsLimit).toList();

/// The Shop page's search, filters and sort. The URL is the source of truth,
/// so views survive reload and Back, and can be shared.
class CatalogQuery {
  const CatalogQuery({
    this.search = '',
    this.categoryId,
    this.sort = CatalogueSort.newest,
    this.availability = CatalogueAvailability.any,
  });

  /// Unknown or missing values fall back to the defaults.
  factory CatalogQuery.fromUri(Uri uri) {
    final params = uri.queryParameters;
    final category = params['categoryId']?.trim();
    return CatalogQuery(
      search: params['q'] ?? '',
      categoryId: category == null || category.isEmpty ? null : category,
      sort: CatalogueSort.values.firstWhere(
        (value) => value.param == params['sort'],
        orElse: () => CatalogueSort.newest,
      ),
      availability: CatalogueAvailability.values.firstWhere(
        (value) => value.param == params['stock'],
        orElse: () => CatalogueAvailability.any,
      ),
    );
  }

  final String search;
  final String? categoryId;
  final CatalogueSort sort;
  final CatalogueAvailability availability;

  /// Filters that change which products match. Sort only changes their order.
  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      categoryId != null ||
      availability != CatalogueAvailability.any;

  /// How many options in the filter sheet differ from their defaults.
  int get activeOptionCount =>
      (categoryId != null ? 1 : 0) +
      (availability != CatalogueAvailability.any ? 1 : 0) +
      (sort != CatalogueSort.newest ? 1 : 0);

  CatalogQuery copyWith({
    String? search,
    String? Function()? categoryId,
    CatalogueSort? sort,
    CatalogueAvailability? availability,
  }) => CatalogQuery(
    search: search ?? this.search,
    categoryId: categoryId == null ? this.categoryId : categoryId(),
    sort: sort ?? this.sort,
    availability: availability ?? this.availability,
  );

  /// The Shop URL for this query, leaving out anything at its default.
  String toLocation() {
    final trimmed = search.trim();
    final params = {
      'categoryId': ?categoryId,
      if (trimmed.isNotEmpty) 'q': trimmed,
      if (sort != CatalogueSort.newest) 'sort': sort.param,
      if (availability != CatalogueAvailability.any)
        'stock': availability.param,
    };
    return params.isEmpty
        ? '/shop'
        : Uri(path: '/shop', queryParameters: params).toString();
  }

  List<Product> apply(Iterable<Product> products) {
    final term = search.trim().toLowerCase();
    final matches = products.where((product) {
      if (!product.isActive) return false;
      if (term.isNotEmpty && !product.name.toLowerCase().contains(term)) {
        return false;
      }
      if (categoryId != null && product.categoryId != categoryId) return false;
      return switch (availability) {
        CatalogueAvailability.any => true,
        CatalogueAvailability.inStock => product.isPurchasable,
        CatalogueAvailability.outOfStock => !product.isPurchasable,
      };
    }).toList();

    int byName(Product a, Product b) => a.name.compareTo(b.name);
    matches.sort(switch (sort) {
      CatalogueSort.newest => _newestFirst,
      CatalogueSort.priceLowToHigh => (a, b) {
        final byPrice = a.price.compareTo(b.price);
        return byPrice != 0 ? byPrice : byName(a, b);
      },
      CatalogueSort.priceHighToLow => (a, b) {
        final byPrice = b.price.compareTo(a.price);
        return byPrice != 0 ? byPrice : byName(a, b);
      },
    });
    return matches;
  }
}
