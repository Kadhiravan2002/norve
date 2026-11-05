import 'package:flutter_test/flutter_test.dart';
import 'package:norve/features/products/product.dart';
import 'package:norve_customer_web/catalog/catalog_query.dart';

Product item(
  String name, {
  int price = 1000,
  String category = 'tops',
  int stock = 5,
  bool active = true,
  DateTime? created,
}) => Product(
  id: name,
  name: name,
  price: price,
  imageUrl: '',
  category: category,
  categoryId: category,
  description: '',
  sizes: const [],
  colors: const [],
  isActive: active,
  createdAt: created,
  variants: [
    ProductVariant(
      size: 'M',
      colorName: 'Black',
      colorValue: 0xFF000000,
      stockQuantity: stock,
    ),
  ],
);

List<String> names(Iterable<Product> products) =>
    products.map((product) => product.name).toList();

void main() {
  final catalogue = [
    item('Linen Shirt', price: 2000, created: DateTime(2026, 1, 2)),
    item('Cotton Tee', price: 800, created: DateTime(2026, 1, 3)),
    item(
      'Wool Coat',
      price: 5000,
      category: 'outer',
      stock: 0,
      created: DateTime(2026, 1, 1),
    ),
    item(
      'Hidden Coat',
      price: 100,
      active: false,
      created: DateTime(2026, 2, 1),
    ),
  ];

  group('apply', () {
    test('defaults show active products, newest first', () {
      expect(names(const CatalogQuery().apply(catalogue)), [
        'Cotton Tee',
        'Linen Shirt',
        'Wool Coat',
      ]);
    });

    test('search matches the name only, ignoring case and spaces', () {
      expect(names(const CatalogQuery(search: '  COAT ').apply(catalogue)), [
        'Wool Coat',
      ]);
      expect(const CatalogQuery(search: 'tops').apply(catalogue), isEmpty);
    });

    test('filters by category', () {
      expect(names(const CatalogQuery(categoryId: 'outer').apply(catalogue)), [
        'Wool Coat',
      ]);
    });

    test('filters by availability', () {
      expect(
        names(
          const CatalogQuery(availability: CatalogueAvailability.outOfStock)
              .apply(catalogue),
        ),
        ['Wool Coat'],
      );
      expect(
        names(
          const CatalogQuery(availability: CatalogueAvailability.inStock)
              .apply(catalogue),
        ),
        ['Cotton Tee', 'Linen Shirt'],
      );
    });

    test('sorts by price both ways', () {
      expect(
        names(
          const CatalogQuery(sort: CatalogueSort.priceLowToHigh)
              .apply(catalogue),
        ),
        ['Cotton Tee', 'Linen Shirt', 'Wool Coat'],
      );
      expect(
        names(
          const CatalogQuery(sort: CatalogueSort.priceHighToLow)
              .apply(catalogue),
        ),
        ['Wool Coat', 'Linen Shirt', 'Cotton Tee'],
      );
    });

    test('combines search, filter and sort', () {
      expect(
        names(
          const CatalogQuery(
            search: 't',
            categoryId: 'tops',
            sort: CatalogueSort.priceLowToHigh,
            availability: CatalogueAvailability.inStock,
          ).apply(catalogue),
        ),
        ['Cotton Tee', 'Linen Shirt'],
      );
    });

    test('equal timestamps keep a stable order', () {
      final date = DateTime(2026, 1, 1);
      final tied = [item('B', created: date), item('A', created: date)];
      expect(names(const CatalogQuery().apply(tied)), ['A', 'B']);
    });

    test('undated products sort last', () {
      final mixed = [item('Undated'), item('Dated', created: DateTime(2026))];
      expect(names(const CatalogQuery().apply(mixed)), ['Dated', 'Undated']);
    });
  });

  group('URL round trip', () {
    test('defaults produce a clean URL', () {
      expect(const CatalogQuery().toLocation(), '/shop');
    });

    test('every option survives a round trip', () {
      const query = CatalogQuery(
        search: 'linen shirt',
        categoryId: 'abc',
        sort: CatalogueSort.priceHighToLow,
        availability: CatalogueAvailability.outOfStock,
      );
      final parsed = CatalogQuery.fromUri(Uri.parse(query.toLocation()));
      expect(parsed.search, 'linen shirt');
      expect(parsed.categoryId, 'abc');
      expect(parsed.sort, CatalogueSort.priceHighToLow);
      expect(parsed.availability, CatalogueAvailability.outOfStock);
    });

    test('special characters in a search survive a round trip', () {
      const query = CatalogQuery(search: 'a&b=c #d');
      expect(
        CatalogQuery.fromUri(Uri.parse(query.toLocation())).search,
        'a&b=c #d',
      );
    });

    test('invalid values fall back to the defaults', () {
      final parsed = CatalogQuery.fromUri(
        Uri.parse('/shop?sort=nonsense&stock=maybe&categoryId='),
      );
      expect(parsed.sort, CatalogueSort.newest);
      expect(parsed.availability, CatalogueAvailability.any);
      expect(parsed.categoryId, isNull);
    });

    test('the mobile category parameter is understood', () {
      expect(
        CatalogQuery.fromUri(Uri.parse('/shop?categoryId=xyz')).categoryId,
        'xyz',
      );
    });
  });

  test('copyWith can clear the category', () {
    const query = CatalogQuery(categoryId: 'abc', search: 'x');
    final cleared = query.copyWith(categoryId: () => null);
    expect(cleared.categoryId, isNull);
    expect(cleared.search, 'x');
    expect(query.copyWith(search: 'y').categoryId, 'abc');
  });

  test('active option count ignores search and counts sort', () {
    expect(const CatalogQuery(search: 'x').activeOptionCount, 0);
    expect(
      const CatalogQuery(
        categoryId: 'a',
        sort: CatalogueSort.priceLowToHigh,
        availability: CatalogueAvailability.inStock,
      ).activeOptionCount,
      3,
    );
  });

  test('sort alone does not count as filtering for the empty message', () {
    expect(
      const CatalogQuery(sort: CatalogueSort.priceLowToHigh).hasActiveFilters,
      isFalse,
    );
    expect(const CatalogQuery(search: 'x').hasActiveFilters, isTrue);
  });

  group('new arrivals', () {
    test('returns the newest 12 active products', () {
      final many = [
        for (var i = 1; i <= 20; i++)
          item('P$i', created: DateTime(2026, 1, i)),
        item('Hidden', active: false, created: DateTime(2027)),
      ];
      final result = names(newArrivals(many));
      expect(result, hasLength(newArrivalsLimit));
      expect(result.first, 'P20');
      expect(result.last, 'P9');
      expect(result, isNot(contains('Hidden')));
    });

    test('a small catalogue returns everything', () {
      expect(names(newArrivals(catalogue)), hasLength(3));
    });
  });
}
