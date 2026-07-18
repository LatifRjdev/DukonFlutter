import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/category.dart';

void main() {
  group('Category defaults', () {
    test('sortOrder defaults to 0 and productCount defaults to 0 when omitted', () {
      const category = Category(id: 'c1', storeId: 'store-1', name: 'Drinks');

      expect(category.sortOrder, 0);
      expect(category.productCount, 0);
      expect(category.icon, isNull);
      expect(category.color, isNull);
      expect(category.parentId, isNull);
    });
  });

  group('Category equality', () {
    test('two instances with the same field values are equal', () {
      const a = Category(
        id: 'c1',
        storeId: 'store-1',
        name: 'Drinks',
        icon: 'drink',
        color: '#FF0000',
        sortOrder: 1,
        parentId: 'p1',
        productCount: 5,
      );
      const b = Category(
        id: 'c1',
        storeId: 'store-1',
        name: 'Drinks',
        icon: 'drink',
        color: '#FF0000',
        sortOrder: 1,
        parentId: 'p1',
        productCount: 5,
      );

      expect(a, equals(b));
    });

    test('instances with different ids are not equal', () {
      const a = Category(id: 'c1', storeId: 'store-1', name: 'Drinks');
      const b = Category(id: 'c2', storeId: 'store-1', name: 'Drinks');

      expect(a, isNot(equals(b)));
    });

    test('instances with different names are not equal', () {
      const a = Category(id: 'c1', storeId: 'store-1', name: 'Drinks');
      const b = Category(id: 'c1', storeId: 'store-1', name: 'Snacks');

      expect(a, isNot(equals(b)));
    });

    test('instances with different sortOrder are not equal', () {
      const a = Category(id: 'c1', storeId: 'store-1', name: 'Drinks', sortOrder: 1);
      const b = Category(id: 'c1', storeId: 'store-1', name: 'Drinks', sortOrder: 2);

      expect(a, isNot(equals(b)));
    });

    // Category.props omits productCount (see lib/domain/entities/category.dart),
    // so Equatable treats two categories that differ only in productCount as
    // equal. This is almost certainly unintentional (e.g. a bloc rebuild that
    // only changes productCount would not trigger a UI update), but we pin
    // the current behavior here rather than silently "fixing" a domain
    // entity outside the scope of this test-coverage task.
    test(
        'instances that differ only in productCount ARE equal '
        '(productCount is excluded from props — likely a bug)', () {
      const a = Category(
        id: 'c1',
        storeId: 'store-1',
        name: 'Drinks',
        productCount: 3,
      );
      const b = Category(
        id: 'c1',
        storeId: 'store-1',
        name: 'Drinks',
        productCount: 99,
      );

      expect(a, equals(b));
    });
  });
}
