import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/domain/entities/shift.dart';

void main() {
  // The API nests the cashier under staff.user and sends no flat staffName,
  // so the shifts screen rendered "Кассир: Не указан" for a shift whose
  // cashier the Сотрудники screen listed by name.
  Map<String, dynamic> payload(Map<String, dynamic> extra) => {
        'id': 'sh1',
        'storeId': 'st1',
        'staffId': 'stf1',
        'openedAt': '2026-10-02T08:57:27.332Z',
        'openingCash': 500,
        'status': 'OPEN',
        ...extra,
      };

  test('should read the cashier name from the nested staff object when no '
      'flat staffName is sent', () {
    final shift = ShiftModel.fromJson(payload({
      'staff': {
        'id': 'stf1',
        'user': {'id': 'u1', 'name': 'QA Бизнес'},
      },
    }));

    expect(shift.staffName, 'QA Бизнес');
  });

  test('should prefer a flat staffName when the API sends one', () {
    final shift = ShiftModel.fromJson(payload({
      'staffName': 'Flat Name',
      'staff': {
        'user': {'name': 'Nested Name'},
      },
    }));

    expect(shift.staffName, 'Flat Name');
  });

  test('should report no cashier name when neither shape carries one', () {
    expect(ShiftModel.fromJson(payload({})).staffName, isNull);
    expect(ShiftModel.fromJson(payload({'staff': <String, dynamic>{}})).staffName,
        isNull);
  });
}
