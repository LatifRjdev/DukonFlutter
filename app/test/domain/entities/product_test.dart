import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/product.dart';

void main() {
  Product mkProduct({
    String id = 'p1',
    String storeId = 'store-1',
    String? categoryId,
    String? categoryName,
    String? supplierId,
    String name = 'Apple',
    String? sku,
    String? barcode,
    String? description,
    double? costPrice,
    double sellPrice = 10,
    double? wholesalePrice,
    int quantity = 0,
    int minQuantity = 0,
    String unit = 'PCS',
    String? imageUrl,
    bool isActive = true,
    DateTime? createdAt,
  }) =>
      Product(
        id: id,
        storeId: storeId,
        categoryId: categoryId,
        categoryName: categoryName,
        supplierId: supplierId,
        name: name,
        sku: sku,
        barcode: barcode,
        description: description,
        costPrice: costPrice,
        sellPrice: sellPrice,
        wholesalePrice: wholesalePrice,
        quantity: quantity,
        minQuantity: minQuantity,
        unit: unit,
        imageUrl: imageUrl,
        isActive: isActive,
        createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
      );

  group('Product defaults', () {
    test('applies default values when optional constructor args are omitted',
        () {
      final product = Product(
        id: 'p1',
        storeId: 'store-1',
        name: 'Apple',
        sellPrice: 10,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      expect(product.quantity, 0);
      expect(product.minQuantity, 0);
      expect(product.unit, 'PCS');
      expect(product.isActive, isTrue);
      expect(product.categoryId, isNull);
      expect(product.categoryName, isNull);
      expect(product.supplierId, isNull);
      expect(product.sku, isNull);
      expect(product.barcode, isNull);
      expect(product.description, isNull);
      expect(product.costPrice, isNull);
      expect(product.wholesalePrice, isNull);
      expect(product.imageUrl, isNull);
    });
  });

  group('Product.isLowStock', () {
    test('is false when quantity is above minQuantity', () {
      final product = mkProduct(quantity: 10, minQuantity: 5);
      expect(product.isLowStock, isFalse);
    });

    test('is true when quantity equals minQuantity and both are positive',
        () {
      final product = mkProduct(quantity: 5, minQuantity: 5);
      expect(product.isLowStock, isTrue);
    });

    test('is true when quantity is below minQuantity', () {
      final product = mkProduct(quantity: 1, minQuantity: 5);
      expect(product.isLowStock, isTrue);
    });

    test('is false when quantity is zero, even if minQuantity is positive',
        () {
      // isOutOfStock should own the zero-quantity case, not isLowStock.
      final product = mkProduct(quantity: 0, minQuantity: 5);
      expect(product.isLowStock, isFalse);
    });
  });

  group('Product.isOutOfStock', () {
    test('is true when quantity is zero', () {
      expect(mkProduct(quantity: 0).isOutOfStock, isTrue);
    });

    test('is true when quantity is negative', () {
      expect(mkProduct(quantity: -1).isOutOfStock, isTrue);
    });

    test('is false when quantity is positive', () {
      expect(mkProduct(quantity: 1).isOutOfStock, isFalse);
    });
  });

  group('Product.profit', () {
    test('is null when costPrice is null', () {
      final product = mkProduct(sellPrice: 10, costPrice: null);
      expect(product.profit, isNull);
    });

    test('is sellPrice - costPrice when costPrice is set', () {
      final product = mkProduct(sellPrice: 10, costPrice: 6);
      expect(product.profit, 4);
    });

    test('can be negative when costPrice exceeds sellPrice', () {
      final product = mkProduct(sellPrice: 5, costPrice: 8);
      expect(product.profit, -3);
    });
  });

  group('Product.margin', () {
    test('is null when costPrice is null', () {
      final product = mkProduct(sellPrice: 10, costPrice: null);
      expect(product.margin, isNull);
    });

    test('is null when costPrice is zero (avoids treating 0 as a real cost)',
        () {
      final product = mkProduct(sellPrice: 10, costPrice: 0);
      expect(product.margin, isNull);
    });

    test('computes (sellPrice - costPrice) / sellPrice * 100', () {
      final product = mkProduct(sellPrice: 20, costPrice: 5);
      expect(product.margin, 75);
    });

    test('is negative when costPrice exceeds sellPrice', () {
      final product = mkProduct(sellPrice: 10, costPrice: 20);
      expect(product.margin, -100);
    });
  });

  group('Product equality (Equatable props)', () {
    test('two products with identical prop fields are equal', () {
      final a = mkProduct(id: 'p1', sku: 'A1', barcode: '123', quantity: 3);
      final b = mkProduct(id: 'p1', sku: 'A1', barcode: '123', quantity: 3);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('products differing only in fields outside props are still equal',
        () {
      // description, costPrice, categoryId, createdAt etc. are NOT in props.
      final a = mkProduct(
        id: 'p1',
        description: 'desc A',
        costPrice: 1,
        createdAt: DateTime.utc(2020, 1, 1),
      );
      final b = mkProduct(
        id: 'p1',
        description: 'desc B',
        costPrice: 99,
        createdAt: DateTime.utc(2026, 6, 1),
      );
      expect(a, equals(b));
    });

    test('products differing in id are not equal', () {
      final a = mkProduct(id: 'p1');
      final b = mkProduct(id: 'p2');
      expect(a, isNot(equals(b)));
    });

    test('products differing in sellPrice are not equal', () {
      final a = mkProduct(sellPrice: 10);
      final b = mkProduct(sellPrice: 20);
      expect(a, isNot(equals(b)));
    });

    test('products differing in isActive are not equal', () {
      final a = mkProduct(isActive: true);
      final b = mkProduct(isActive: false);
      expect(a, isNot(equals(b)));
    });
  });
}
