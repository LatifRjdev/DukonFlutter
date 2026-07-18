import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/sale.dart';
import 'package:dukonpro/domain/entities/sale_item.dart';
import 'package:dukonpro/data/models/sale_model.dart';
import 'package:dukonpro/data/models/sale_item_model.dart';

// Sale is a plain Equatable data class with no JSON logic of its own;
// SaleModel is the JSON/SQLite representation used for local caching and
// has no dedicated test coverage anywhere else in the suite (the remote
// datasource has its own separate inline parsing, already covered by
// sale_remote_datasource_test.dart, and is out of scope here).

Sale _makeSale({
  String id = 'sale-1',
  String storeId = 'store-1',
  String? customerId,
  String? customerName,
  String receiptNo = 'R-001',
  double subtotal = 100,
  double discount = 0,
  double total = 100,
  String paymentType = 'CASH',
  double paidAmount = 100,
  double change = 0,
  double debtAmount = 0,
  String status = 'COMPLETED',
  List<SaleItem> items = const [],
  DateTime? createdAt,
  int pointsEarned = 0,
  int pointsBalance = 0,
}) {
  return Sale(
    id: id,
    storeId: storeId,
    customerId: customerId,
    customerName: customerName,
    receiptNo: receiptNo,
    subtotal: subtotal,
    discount: discount,
    total: total,
    paymentType: paymentType,
    paidAmount: paidAmount,
    change: change,
    debtAmount: debtAmount,
    status: status,
    items: items,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    pointsEarned: pointsEarned,
    pointsBalance: pointsBalance,
  );
}

void main() {
  group('Sale defaults', () {
    test('applies default values when optional constructor args are omitted',
        () {
      final sale = Sale(
        id: 'sale-1',
        storeId: 'store-1',
        receiptNo: 'R-001',
        subtotal: 100,
        total: 100,
        paymentType: 'CASH',
        paidAmount: 100,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(sale.discount, 0);
      expect(sale.discountType, isNull);
      expect(sale.change, 0);
      expect(sale.debtAmount, 0);
      expect(sale.dueDate, isNull);
      expect(sale.status, 'COMPLETED');
      expect(sale.notes, isNull);
      expect(sale.items, isEmpty);
      expect(sale.pointsEarned, 0);
      expect(sale.pointsBalance, 0);
      expect(sale.customerId, isNull);
      expect(sale.customerName, isNull);
      expect(sale.staffId, isNull);
      expect(sale.shiftId, isNull);
    });
  });

  group('Sale equality (Equatable)', () {
    test('two sales with identical props are equal', () {
      expect(_makeSale(), _makeSale());
    });

    test('differs when id differs', () {
      expect(_makeSale(id: 's1'), isNot(_makeSale(id: 's2')));
    });

    test('differs when storeId differs', () {
      expect(_makeSale(storeId: 'a'), isNot(_makeSale(storeId: 'b')));
    });

    test('differs when receiptNo differs', () {
      expect(
        _makeSale(receiptNo: 'R-001'),
        isNot(_makeSale(receiptNo: 'R-002')),
      );
    });

    test('differs when total differs', () {
      expect(_makeSale(total: 100), isNot(_makeSale(total: 200)));
    });

    test('differs when status differs', () {
      expect(
        _makeSale(status: 'COMPLETED'),
        isNot(_makeSale(status: 'REFUNDED')),
      );
    });

    test('differs when createdAt differs', () {
      expect(
        _makeSale(createdAt: DateTime(2026, 1, 1)),
        isNot(_makeSale(createdAt: DateTime(2026, 2, 1))),
      );
    });

    // NOTE: props deliberately excludes paymentType/subtotal/discount/
    // paidAmount/items/customerId, so two sales that look very different
    // (different customer, different line items, different payment method)
    // compare equal as long as id/storeId/receiptNo/total/status/createdAt
    // match. Documenting the actual behavior rather than asserting it's a
    // bug — this mirrors SaleItem's props list and is presumably
    // intentional (identity-ish equality for list diffing).
    test('is equal even when paymentType/customerId/items differ, because '
        'they are not part of props', () {
      final a = _makeSale(
        paymentType: 'CASH',
        customerId: null,
        items: const [],
      );
      final b = _makeSale(
        paymentType: 'CARD',
        customerId: 'c1',
        items: [
          const SaleItem(
            id: 'i1',
            saleId: 'sale-1',
            productId: 'p1',
            productName: 'Apple',
            quantity: 1,
            unitPrice: 10,
            total: 10,
          ),
        ],
      );
      expect(a, b);
    });
  });

  group('SaleModel.fromJson / toJson', () {
    Map<String, dynamic> validJson() => {
          'id': 'sale-1',
          'storeId': 'store-1',
          'customerId': 'c1',
          'customerName': 'Ali',
          'staffId': 'staff-1',
          'shiftId': 'shift-1',
          'receiptNo': 'R-001',
          'subtotal': 100.0,
          'discount': 10.0,
          'discountType': 'FIXED',
          'total': 90.0,
          'paymentType': 'CASH',
          'paidAmount': 90.0,
          'change': 0.0,
          'debtAmount': 0.0,
          'dueDate': null,
          'status': 'COMPLETED',
          'notes': 'note',
          'items': [
            {
              'id': 'i1',
              'saleId': 'sale-1',
              'productId': 'p1',
              'productName': 'Apple',
              'quantity': 2,
              'unitPrice': 10.0,
              'costPrice': 5.0,
              'discount': 0.0,
              'total': 20.0,
            }
          ],
          'createdAt': '2026-01-01T00:00:00.000Z',
        };

    test('parses a fully populated JSON row including nested items', () {
      final model = SaleModel.fromJson(validJson());

      expect(model.id, 'sale-1');
      expect(model.customerId, 'c1');
      expect(model.subtotal, 100.0);
      expect(model.discount, 10.0);
      expect(model.total, 90.0);
      expect(model.items, hasLength(1));
      expect(model.items.first.productName, 'Apple');
      expect(model.createdAt, DateTime.parse('2026-01-01T00:00:00.000Z'));
    });

    test('defaults discount/change/debtAmount to 0 when absent', () {
      final json = validJson()
        ..remove('discount')
        ..remove('change')
        ..remove('debtAmount');
      final model = SaleModel.fromJson(json);

      expect(model.discount, 0);
      expect(model.change, 0);
      expect(model.debtAmount, 0);
    });

    test('defaults status to COMPLETED when absent', () {
      final json = validJson()..remove('status');
      final model = SaleModel.fromJson(json);
      expect(model.status, 'COMPLETED');
    });

    test('defaults items to an empty list when the items key is null', () {
      final json = validJson()..['items'] = null;
      final model = SaleModel.fromJson(json);
      expect(model.items, isEmpty);
    });

    test('parses a non-null dueDate', () {
      final json = validJson()..['dueDate'] = '2026-02-01T00:00:00.000Z';
      final model = SaleModel.fromJson(json);
      expect(model.dueDate, DateTime.parse('2026-02-01T00:00:00.000Z'));
    });

    test('accepts integer JSON numbers for double fields without throwing',
        () {
      final json = validJson()
        ..['subtotal'] = 100
        ..['total'] = 90
        ..['paidAmount'] = 90;
      final model = SaleModel.fromJson(json);
      expect(model.subtotal, 100.0);
      expect(model.total, 90.0);
      expect(model.paidAmount, 90.0);
    });

    test('throws when a required field (total) is missing', () {
      final json = validJson()..remove('total');
      expect(() => SaleModel.fromJson(json), throwsA(anything));
    });

    test('round-trips fromJson -> toJson including nested items', () {
      final json = validJson();
      final model = SaleModel.fromJson(json);
      final result = model.toJson();

      expect(result['id'], json['id']);
      expect(result['total'], json['total']);
      expect(result['discount'], json['discount']);
      expect((result['items'] as List).length, 1);
      expect(
        (result['items'] as List).first['productName'],
        'Apple',
      );
      expect(result['createdAt'], model.createdAt.toIso8601String());
    });
  });

  group('SaleModel.fromMap / toMap (SQLite)', () {
    // fromMap/toMap intentionally do not carry items — items live in a
    // separate sale_items table and are passed in explicitly.
    Map<String, dynamic> validMap() => {
          'id': 'sale-1',
          'store_id': 'store-1',
          'customer_id': 'c1',
          'customer_name': 'Ali',
          'staff_id': 'staff-1',
          'shift_id': 'shift-1',
          'receipt_no': 'R-001',
          'subtotal': 100.0,
          'discount': 10.0,
          'discount_type': 'FIXED',
          'total': 90.0,
          'payment_type': 'CASH',
          'paid_amount': 90.0,
          'change_amount': 0.0,
          'debt_amount': 0.0,
          'due_date': null,
          'status': 'COMPLETED',
          'notes': null,
          'created_at': '2026-01-01T00:00:00.000Z',
        };

    test('parses snake_case SQLite columns and defaults items to empty', () {
      final model = SaleModel.fromMap(validMap());
      expect(model.storeId, 'store-1');
      expect(model.paymentType, 'CASH');
      expect(model.items, isEmpty);
    });

    test('accepts an explicit items list passed alongside the row', () {
      const item = SaleItemModel(
        id: 'i1',
        saleId: 'sale-1',
        productId: 'p1',
        productName: 'Apple',
        quantity: 1,
        unitPrice: 10,
        total: 10,
      );
      final model = SaleModel.fromMap(validMap(), items: const [item]);
      expect(model.items, hasLength(1));
      expect(model.items.first.productName, 'Apple');
    });

    test('toMap omits items entirely (stored in a separate table)', () {
      final model = SaleModel.fromMap(validMap());
      final result = model.toMap();
      expect(result.containsKey('items'), isFalse);
    });

    test('round-trips fromMap -> toMap without losing scalar data', () {
      final map = validMap();
      final model = SaleModel.fromMap(map);
      final result = model.toMap();

      expect(result['id'], map['id']);
      expect(result['store_id'], map['store_id']);
      expect(result['receipt_no'], map['receipt_no']);
      expect(result['total'], map['total']);
      expect(result['payment_type'], map['payment_type']);
    });
  });

  group('SaleModel <-> Sale entity conversion', () {
    test('fromEntity copies scalar fields and maps items via SaleItemModel',
        () {
      final entity = _makeSale(items: [
        const SaleItem(
          id: 'i1',
          saleId: 'sale-1',
          productId: 'p1',
          productName: 'Apple',
          quantity: 1,
          unitPrice: 10,
          total: 10,
        ),
      ]);
      final model = SaleModel.fromEntity(entity);

      expect(model.id, entity.id);
      expect(model.storeId, entity.storeId);
      expect(model.total, entity.total);
      expect(model.items, hasLength(1));
      expect(model.items.first.productName, 'Apple');
    });

    test('toEntity produces a Sale equal to the entity fromEntity was built '
        'from', () {
      final entity = _makeSale();
      final roundTripped = SaleModel.fromEntity(entity).toEntity();
      expect(roundTripped, entity);
    });

    // BUG (minor, non-revenue-blocking): SaleModel has no pointsEarned/
    // pointsBalance fields at all (see lib/data/models/sale_model.dart) —
    // they exist only on the Sale entity and are populated by
    // sale_remote_datasource.dart's own inline parsing. Any Sale that goes
    // through SaleModel.fromEntity/toEntity (i.e. the local cache /
    // offline round-trip in SaleRepositoryImpl) silently loses loyalty
    // points info, resetting it to 0. Not revenue-critical since points
    // are informational display data (see thermal_printer_service.dart),
    // but flagging since a cached/offline sale's receipt reprint would
    // show 0 points even if points were actually earned.
    test('fromEntity -> toEntity silently drops pointsEarned/pointsBalance '
        '(documents the gap noted above)', () {
      final entity = _makeSale(pointsEarned: 15, pointsBalance: 200);
      final roundTripped = SaleModel.fromEntity(entity).toEntity();

      expect(entity.pointsEarned, 15);
      expect(roundTripped.pointsEarned, 0);
      expect(entity.pointsBalance, 200);
      expect(roundTripped.pointsBalance, 0);
    });
  });
}
