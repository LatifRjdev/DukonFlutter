import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/user.dart';

void main() {
  group('User', () {
    final createdAt = DateTime.utc(2026, 1, 1);

    User buildUser({
      String id = 'u1',
      String phone = '+992900000000',
      String name = 'Test User',
      String? email,
      String? avatar,
      bool isActive = true,
      DateTime? createdAtOverride,
    }) =>
        User(
          id: id,
          phone: phone,
          name: name,
          email: email,
          avatar: avatar,
          isActive: isActive,
          createdAt: createdAtOverride ?? createdAt,
        );

    test('isActive defaults to true when not provided', () {
      final user = User(
        id: 'u1',
        phone: '+992900000000',
        name: 'Test User',
        createdAt: createdAt,
      );

      expect(user.isActive, isTrue);
    });

    test('email and avatar default to null when not provided', () {
      final user = User(
        id: 'u1',
        phone: '+992900000000',
        name: 'Test User',
        createdAt: createdAt,
      );

      expect(user.email, isNull);
      expect(user.avatar, isNull);
    });

    test('two users with identical field values are equal', () {
      final a = buildUser();
      final b = buildUser();

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('users with different id are not equal', () {
      final a = buildUser(id: 'u1');
      final b = buildUser(id: 'u2');

      expect(a, isNot(equals(b)));
    });

    test('users with different phone are not equal', () {
      final a = buildUser(phone: '+992900000000');
      final b = buildUser(phone: '+992900000001');

      expect(a, isNot(equals(b)));
    });

    test('users with different name are not equal', () {
      final a = buildUser(name: 'Alice');
      final b = buildUser(name: 'Bob');

      expect(a, isNot(equals(b)));
    });

    test('users with different email are not equal', () {
      final a = buildUser(email: 'a@example.com');
      final b = buildUser(email: 'b@example.com');

      expect(a, isNot(equals(b)));
    });

    test('users with different avatar are not equal', () {
      final a = buildUser(avatar: 'avatar-a.png');
      final b = buildUser(avatar: 'avatar-b.png');

      expect(a, isNot(equals(b)));
    });

    test('users with different isActive are not equal', () {
      final a = buildUser(isActive: true);
      final b = buildUser(isActive: false);

      expect(a, isNot(equals(b)));
    });

    test('users with different createdAt are not equal', () {
      final a = buildUser(createdAtOverride: DateTime.utc(2026, 1, 1));
      final b = buildUser(createdAtOverride: DateTime.utc(2026, 1, 2));

      expect(a, isNot(equals(b)));
    });

    test('props includes all seven fields in a stable order', () {
      final user = buildUser(email: 'e@x.com', avatar: 'a.png');

      expect(user.props, [
        user.id,
        user.phone,
        user.name,
        user.email,
        user.avatar,
        user.isActive,
        user.createdAt,
      ]);
    });
  });
}
