import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/core/network/api_list_response.dart';

// Minimal, dependency-free unit tests for the shared list/object decoders.
// These cover the three historical response shapes that crashed staff,
// customers, and suppliers screens (FD-P0-002 / 004 / 005) so a future
// refactor of ApiListResponse cannot silently regress the crash fix.

class _FakeItem {
  _FakeItem(this.id, this.name);
  final String id;
  final String name;

  factory _FakeItem.fromJson(Map<String, dynamic> json) =>
      _FakeItem(json['id'] as String, json['name'] as String);
}

void main() {
  group('ApiListResponse.decode', () {
    test('accepts a bare JSON array (staff shape)', () {
      final raw = [
        {'id': '1', 'name': 'Ali'},
        {'id': '2', 'name': 'Bek'},
      ];

      final decoded = ApiListResponse.decode<_FakeItem>(raw, _FakeItem.fromJson);

      expect(decoded.items.length, 2);
      expect(decoded.items.first.name, 'Ali');
      expect(decoded.total, 2);
      expect(decoded.totalPages, 1);
    });

    test('accepts {data: [...], total, totalPages} (customers/suppliers shape)',
        () {
      final raw = {
        'data': [
          {'id': 'a', 'name': 'One'},
        ],
        'total': 42,
        'page': 1,
        'limit': 20,
        'totalPages': 3,
      };

      final decoded = ApiListResponse.decode<_FakeItem>(raw, _FakeItem.fromJson);

      expect(decoded.items.single.name, 'One');
      expect(decoded.total, 42);
      expect(decoded.totalPages, 3);
    });

    test('accepts legacy {data: {items: [...], total, totalPages}} shape', () {
      final raw = {
        'data': {
          'items': [
            {'id': 'x', 'name': 'Legacy'},
          ],
          'total': 7,
          'totalPages': 2,
        },
      };

      final decoded = ApiListResponse.decode<_FakeItem>(raw, _FakeItem.fromJson);

      expect(decoded.items.single.name, 'Legacy');
      expect(decoded.total, 7);
      expect(decoded.totalPages, 2);
    });

    test('returns empty list on null / empty string / unexpected shape', () {
      for (final raw in <dynamic>[null, '', 42, {'totally': 'wrong'}]) {
        final decoded =
            ApiListResponse.decode<_FakeItem>(raw, _FakeItem.fromJson);
        expect(decoded.items, isEmpty,
            reason: 'unexpected shape $raw should not crash');
        expect(decoded.totalPages, 1);
      }
    });

    test('ignores non-map elements inside the array', () {
      final raw = [
        {'id': '1', 'name': 'Real'},
        'garbage',
        null,
        42,
      ];

      final decoded = ApiListResponse.decode<_FakeItem>(raw, _FakeItem.fromJson);

      expect(decoded.items.length, 1);
      expect(decoded.items.single.id, '1');
    });
  });

  group('decodeApiObject', () {
    test('returns the payload as-is for a plain map', () {
      final result = decodeApiObject({'id': 'x', 'name': 'Plain'});
      expect(result, isNotNull);
      expect(result!['id'], 'x');
    });

    test('unwraps {data: {...}} envelopes', () {
      final result = decodeApiObject({
        'data': {'id': 'y', 'name': 'Wrapped'},
      });
      expect(result, isNotNull);
      expect(result!['name'], 'Wrapped');
    });

    test('returns null for non-map payloads', () {
      expect(decodeApiObject(null), isNull);
      expect(decodeApiObject(''), isNull);
      expect(decodeApiObject([1, 2, 3]), isNull);
      expect(decodeApiObject(42), isNull);
    });
  });
}
