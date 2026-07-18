import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/sale_item.dart';
import 'package:dukonpro/data/models/sale_item_model.dart';

// SaleItem is a plain Equatable data class with no JSON logic of its own;
// SaleItemModel is the only place fromJson/fromMap/toEntity conversion
// happens for it, and it has no dedicated test coverage anywhere else in
// the suite (sale_remote_datasource_test.dart parses Sale directly, not
// via SaleItemModel) — so both are covered here.

SaleItem _makeItem({
  String id = 'item-1',
  String saleId = 'sale-1',
  String productId = 'p1',
  String productName = 'Apple',
  int quantity = 2,
  double unitPrice = 10,
  double? costPrice = 5,
  double discount = 0,
  double total = 20,
}) {
  return SaleItem(
    id: id,
    saleId: saleId,
    productId: productId,
    productName: productName,
    quantity: quantity,
    unitPrice: unitPrice,
    costPrice: costPrice,
    discount: discount,
    total: total,
  );
}

void main() {
  group('SaleItem defaults', () {
    test('applies default values when optional constructor args are omitted',
        () {
      const item = SaleItem(
        id: 'item-1',
        saleId: 'sale-1',
        productId: 'p1',
        productName: 'Apple',
        quantity: 1,
        unitPrice: 10,
        total: 10,
      );

      expect(item.costPrice, isNull);
      expect(item.discount, 0);
    });
  });

  group('SaleItem equality (Equatable)', () {
    test('two items with identical props are equal', () {
      expect(_makeItem(), _makeItem());
    });

    test('differs when id differs', () {
      expect(_makeItem(id: 'item-1'), isNot(_makeItem(id: 'item-2')));
    });

    test('differs when saleId differs', () {
      expect(_makeItem(saleId: 'sale-1'), isNot(_makeItem(saleId: 'sale-2')));
    });

    test('differs when productId differs', () {
      expect(_makeItem(productId: 'p1'), isNot(_makeItem(productId: 'p2')));
    });

    test('differs when quantity differs', () {
      expect(_makeItem(quantity: 2), isNot(_makeItem(quantity: 3)));
    });

    test('differs when total differs', () {
      expect(_makeItem(total: 20), isNot(_makeItem(total: 30)));
    });

    // NOTE: props deliberately excludes productName/unitPrice/costPrice/
    // discount, so two otherwise-different-looking items compare equal as
    // long as id/saleId/productId/quantity/total match. Documenting this
    // rather than asserting it's a "bug" since Sale has the same pattern.
    test('is equal even when productName differs, because productName is '
        'not part of props', () {
      expect(
        _makeItem(productName: 'Apple'),
        _makeItem(productName: 'Banana'),
      );
    });

    test('is equal even when unitPrice/costPrice/discount differ, because '
        'they are not part of props', () {
      expect(
        _makeItem(unitPrice: 10, costPrice: 5, discount: 0),
        _makeItem(unitPrice: 999, costPrice: 1, discount: 50),
      );
    });
  });

  group('SaleItemModel.fromJson / toJson', () {
    Map<String, dynamic> validJson() => {
          'id': 'item-1',
          'saleId': 'sale-1',
          'productId': 'p1',
          'productName': 'Apple',
          'quantity': 2,
          'unitPrice': 10.5,
          'costPrice': 5.5,
          'discount': 1.0,
          'total': 20.0,
        };

    test('parses a fully populated JSON row', () {
      final model = SaleItemModel.fromJson(validJson());

      expect(model.id, 'item-1');
      expect(model.saleId, 'sale-1');
      expect(model.productId, 'p1');
      expect(model.productName, 'Apple');
      expect(model.quantity, 2);
      expect(model.unitPrice, 10.5);
      expect(model.costPrice, 5.5);
      expect(model.discount, 1.0);
      expect(model.total, 20.0);
    });

    test('defaults discount to 0 when absent', () {
      final json = validJson()..remove('discount');
      final model = SaleItemModel.fromJson(json);
      expect(model.discount, 0);
    });

    test('parses null costPrice as null', () {
      final json = validJson()..['costPrice'] = null;
      final model = SaleItemModel.fromJson(json);
      expect(model.costPrice, isNull);
    });

    test('accepts integer JSON numbers for double fields (unitPrice/total) '
        'without throwing', () {
      final json = validJson()
        ..['unitPrice'] = 10
        ..['total'] = 20;
      final model = SaleItemModel.fromJson(json);
      expect(model.unitPrice, 10.0);
      expect(model.total, 20.0);
    });

    test('round-trips fromJson -> toJson without losing data', () {
      final json = validJson();
      final model = SaleItemModel.fromJson(json);
      final result = model.toJson();

      expect(result['id'], json['id']);
      expect(result['saleId'], json['saleId']);
      expect(result['productId'], json['productId']);
      expect(result['productName'], json['productName']);
      expect(result['quantity'], json['quantity']);
      expect(result['unitPrice'], json['unitPrice']);
      expect(result['costPrice'], json['costPrice']);
      expect(result['discount'], json['discount']);
      expect(result['total'], json['total']);
    });

    test('throws when a required field (total) is missing', () {
      final json = validJson()..remove('total');
      expect(() => SaleItemModel.fromJson(json), throwsA(anything));
    });
  });

  group('SaleItemModel.fromMap / toMap (SQLite)', () {
    Map<String, dynamic> validMap() => {
          'id': 'item-1',
          'sale_id': 'sale-1',
          'product_id': 'p1',
          'product_name': 'Apple',
          'quantity': 2,
          'unit_price': 10.0,
          'cost_price': 5.0,
          'discount': 0.0,
          'total': 20.0,
        };

    test('parses snake_case SQLite columns', () {
      final model = SaleItemModel.fromMap(validMap());
      expect(model.saleId, 'sale-1');
      expect(model.productId, 'p1');
      expect(model.productName, 'Apple');
      expect(model.unitPrice, 10.0);
      expect(model.costPrice, 5.0);
    });

    test('defaults discount to 0 and costPrice to null when absent', () {
      final map = validMap()
        ..remove('discount')
        ..['cost_price'] = null;
      final model = SaleItemModel.fromMap(map);
      expect(model.discount, 0);
      expect(model.costPrice, isNull);
    });

    test('round-trips fromMap -> toMap without losing data', () {
      final map = validMap();
      final model = SaleItemModel.fromMap(map);
      final result = model.toMap();

      expect(result['id'], map['id']);
      expect(result['sale_id'], map['sale_id']);
      expect(result['product_id'], map['product_id']);
      expect(result['product_name'], map['product_name']);
      expect(result['quantity'], map['quantity']);
      expect(result['unit_price'], map['unit_price']);
      expect(result['cost_price'], map['cost_price']);
      expect(result['discount'], map['discount']);
      expect(result['total'], map['total']);
    });
  });

  group('SaleItemModel <-> SaleItem entity conversion', () {
    test('fromEntity copies every field verbatim', () {
      final entity = _makeItem();
      final model = SaleItemModel.fromEntity(entity);

      expect(model.id, entity.id);
      expect(model.saleId, entity.saleId);
      expect(model.productId, entity.productId);
      expect(model.productName, entity.productName);
      expect(model.quantity, entity.quantity);
      expect(model.unitPrice, entity.unitPrice);
      expect(model.costPrice, entity.costPrice);
      expect(model.discount, entity.discount);
      expect(model.total, entity.total);
    });

    test('toEntity produces a SaleItem equal to the entity fromEntity was '
        'built from', () {
      final entity = _makeItem();
      final roundTripped = SaleItemModel.fromEntity(entity).toEntity();

      expect(roundTripped, entity);
      expect(roundTripped.productName, entity.productName);
      expect(roundTripped.unitPrice, entity.unitPrice);
    });
  });
}
