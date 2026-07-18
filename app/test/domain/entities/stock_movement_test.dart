import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/data/models/stock_movement_model.dart';
import 'package:dukonpro/domain/entities/stock_movement.dart';

void main() {
  StockMovement mkMovement({
    String id = 'sm-1',
    String productId = 'prod-1',
    String type = 'PURCHASE',
    int quantity = 10,
    double? unitCost,
    double? totalCost,
    String? supplierId,
    String? reference,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
  }) =>
      StockMovement(
        id: id,
        productId: productId,
        type: type,
        quantity: quantity,
        unitCost: unitCost,
        totalCost: totalCost,
        supplierId: supplierId,
        reference: reference,
        notes: notes,
        createdBy: createdBy,
        createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
      );

  group('StockMovement construction', () {
    test('optional fields default to null when omitted', () {
      final movement = StockMovement(
        id: 'sm-1',
        productId: 'prod-1',
        type: 'PURCHASE',
        quantity: 5,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      expect(movement.unitCost, isNull);
      expect(movement.totalCost, isNull);
      expect(movement.supplierId, isNull);
      expect(movement.reference, isNull);
      expect(movement.notes, isNull);
      expect(movement.createdBy, isNull);
    });

    test('retains all fields when fully populated', () {
      final createdAt = DateTime.utc(2026, 5, 12, 12);
      final movement = StockMovement(
        id: 'sm-2',
        productId: 'prod-2',
        type: 'ADJUSTMENT',
        quantity: -3,
        unitCost: 12.5,
        totalCost: -37.5,
        supplierId: 'sup-1',
        reference: 'REF-1',
        notes: 'damaged goods',
        createdBy: 'user-1',
        createdAt: createdAt,
      );

      expect(movement.id, 'sm-2');
      expect(movement.productId, 'prod-2');
      expect(movement.type, 'ADJUSTMENT');
      expect(movement.quantity, -3);
      expect(movement.unitCost, 12.5);
      expect(movement.totalCost, -37.5);
      expect(movement.supplierId, 'sup-1');
      expect(movement.reference, 'REF-1');
      expect(movement.notes, 'damaged goods');
      expect(movement.createdBy, 'user-1');
      expect(movement.createdAt, createdAt);
    });

    test('accepts arbitrary movement type strings (no enum constraint)', () {
      for (final type in [
        'PURCHASE',
        'SALE',
        'ADJUSTMENT',
        'RETURN',
        'TRANSFER',
      ]) {
        final movement = mkMovement(type: type);
        expect(movement.type, type);
      }
    });
  });

  group('StockMovement equality (props)', () {
    test('two movements are equal when id/productId/type/quantity/createdAt match',
        () {
      final a = mkMovement(unitCost: 1, notes: 'a', createdBy: 'u1');
      final b = mkMovement(unitCost: 999, notes: 'different', createdBy: 'u2');

      // props intentionally excludes unitCost/notes/createdBy — equality is
      // keyed on identity-ish fields only.
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('movements differ when id differs', () {
      final a = mkMovement(id: 'sm-1');
      final b = mkMovement(id: 'sm-2');
      expect(a, isNot(equals(b)));
    });

    test('movements differ when productId differs', () {
      final a = mkMovement(productId: 'prod-1');
      final b = mkMovement(productId: 'prod-2');
      expect(a, isNot(equals(b)));
    });

    test('movements differ when type differs', () {
      final a = mkMovement(type: 'PURCHASE');
      final b = mkMovement(type: 'SALE');
      expect(a, isNot(equals(b)));
    });

    test('movements differ when quantity differs', () {
      final a = mkMovement(quantity: 1);
      final b = mkMovement(quantity: 2);
      expect(a, isNot(equals(b)));
    });

    test('movements differ when createdAt differs', () {
      final a = mkMovement(createdAt: DateTime.utc(2026, 1, 1));
      final b = mkMovement(createdAt: DateTime.utc(2026, 1, 2));
      expect(a, isNot(equals(b)));
    });
  });

  // StockMovement itself has no JSON parsing — StockMovementModel is the
  // JSON <-> entity boundary (see lib/data/models/stock_movement_model.dart).
  // Covered here since it's the only code path that produces StockMovement
  // instances from raw API JSON.
  group('StockMovementModel.fromJson -> toEntity', () {
    test('parses a fully populated payload', () {
      final model = StockMovementModel.fromJson({
        'id': 'sm-1',
        'productId': 'prod-1',
        'type': 'PURCHASE',
        'quantity': 10,
        'unitCost': 12.5,
        'totalCost': 125.0,
        'supplierId': 'sup-1',
        'reference': 'REF-1',
        'notes': 'bulk order',
        'createdBy': 'user-1',
        'createdAt': '2026-05-12T12:00:00Z',
      });
      final entity = model.toEntity();

      expect(entity.id, 'sm-1');
      expect(entity.productId, 'prod-1');
      expect(entity.type, 'PURCHASE');
      expect(entity.quantity, 10);
      expect(entity.unitCost, 12.5);
      expect(entity.totalCost, 125.0);
      expect(entity.supplierId, 'sup-1');
      expect(entity.reference, 'REF-1');
      expect(entity.notes, 'bulk order');
      expect(entity.createdBy, 'user-1');
      expect(entity.createdAt, DateTime.parse('2026-05-12T12:00:00Z'));
    });

    test('missing optional fields parse to null without crashing', () {
      final model = StockMovementModel.fromJson({
        'id': 'sm-2',
        'productId': 'prod-2',
        'type': 'SALE',
        'quantity': 3,
        'createdAt': '2026-05-12T12:00:00Z',
      });
      final entity = model.toEntity();

      expect(entity.unitCost, isNull);
      expect(entity.totalCost, isNull);
      expect(entity.supplierId, isNull);
      expect(entity.reference, isNull);
      expect(entity.notes, isNull);
      expect(entity.createdBy, isNull);
    });

    test('explicit null optional fields parse to null without crashing', () {
      final model = StockMovementModel.fromJson({
        'id': 'sm-3',
        'productId': 'prod-3',
        'type': 'RETURN',
        'quantity': 1,
        'unitCost': null,
        'totalCost': null,
        'supplierId': null,
        'reference': null,
        'notes': null,
        'createdBy': null,
        'createdAt': '2026-05-12T12:00:00Z',
      });
      final entity = model.toEntity();

      expect(entity.unitCost, isNull);
      expect(entity.totalCost, isNull);
      expect(entity.supplierId, isNull);
      expect(entity.reference, isNull);
      expect(entity.notes, isNull);
      expect(entity.createdBy, isNull);
    });

    test('numeric fields arriving as JSON ints are coerced to double', () {
      final model = StockMovementModel.fromJson({
        'id': 'sm-4',
        'productId': 'prod-4',
        'type': 'ADJUSTMENT',
        'quantity': 5,
        'unitCost': 10, // int in JSON, not 10.0
        'totalCost': 50, // int in JSON
        'createdAt': '2026-05-12T12:00:00Z',
      });

      expect(model.unitCost, 10.0);
      expect(model.totalCost, 50.0);
      expect(model.unitCost, isA<double>());
      expect(model.totalCost, isA<double>());
    });

    test('round-trips through toJson', () {
      final original = StockMovementModel.fromJson({
        'id': 'sm-5',
        'productId': 'prod-5',
        'type': 'TRANSFER',
        'quantity': 7,
        'unitCost': 2.5,
        'totalCost': 17.5,
        'supplierId': 'sup-9',
        'reference': 'REF-9',
        'notes': 'transfer note',
        'createdBy': 'user-9',
        'createdAt': '2026-05-12T12:00:00Z',
      });

      final json = original.toJson();
      final reparsed = StockMovementModel.fromJson(json);

      expect(reparsed.toEntity(), equals(original.toEntity()));
      expect(reparsed.unitCost, original.unitCost);
      expect(reparsed.totalCost, original.totalCost);
      expect(reparsed.supplierId, original.supplierId);
    });

    test('supports each known movement type string', () {
      for (final type in [
        'PURCHASE',
        'SALE',
        'ADJUSTMENT',
        'RETURN',
        'TRANSFER',
      ]) {
        final model = StockMovementModel.fromJson({
          'id': 'sm-x',
          'productId': 'prod-x',
          'type': type,
          'quantity': 1,
          'createdAt': '2026-05-12T12:00:00Z',
        });
        expect(model.type, type);
      }
    });
  });
}
