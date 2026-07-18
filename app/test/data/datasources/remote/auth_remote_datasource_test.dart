import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/constants/api_endpoints.dart';
import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/auth_remote_datasource.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dio;
  late AuthRemoteDatasourceImpl ds;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    dio = _MockDioClient();
    ds = AuthRemoteDatasourceImpl(dioClient: dio);
  });

  Response<dynamic> resp(dynamic body, {int statusCode = 200}) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: statusCode,
        data: body,
      );

  Map<String, dynamic> validUserJson({
    String id = 'u1',
    String phone = '+992900000000',
    String name = 'Test User',
    String? email = 'user@example.com',
    String? avatar = 'avatar.png',
    bool? isActive = true,
    String? createdAt = '2026-01-01T00:00:00.000Z',
  }) =>
      {
        'id': id,
        'phone': phone,
        'name': name,
        'email': email,
        'avatar': avatar,
        'isActive': isActive,
        'createdAt': createdAt,
      };

  DioException dioError({
    DioExceptionType type = DioExceptionType.badResponse,
    Response<dynamic>? response,
    String? message,
  }) =>
      DioException(
        requestOptions: RequestOptions(path: ''),
        type: type,
        response: response,
        message: message,
      );

  group('register', () {
    test('returns user + tokens on success', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp({
            'user': validUserJson(),
            'accessToken': 'access-tok',
            'refreshToken': 'refresh-tok',
          }));

      final result = await ds.register(
        phone: '+992900000000',
        password: 'StrongPass99',
        name: 'Test User',
      );

      expect(result.user.id, 'u1');
      expect(result.accessToken, 'access-tok');
      expect(result.refreshToken, 'refresh-tok');
    });

    test('posts to the register endpoint with phone/password/name', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp({
            'user': validUserJson(),
            'accessToken': 'access-tok',
            'refreshToken': 'refresh-tok',
          }));

      await ds.register(
        phone: '+992900000000',
        password: 'StrongPass99',
        name: 'Test User',
      );

      final captured = verify(() => dio.post(
            ApiEndpoints.register,
            data: captureAny(named: 'data'),
          )).captured;
      final data = captured.single as Map<String, dynamic>;
      expect(data['phone'], '+992900000000');
      expect(data['password'], 'StrongPass99');
      expect(data['name'], 'Test User');
    });

    test('omits the email key from the request body when email is null',
        () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp({
            'user': validUserJson(),
            'accessToken': 'access-tok',
            'refreshToken': 'refresh-tok',
          }));

      await ds.register(
        phone: '+992900000000',
        password: 'StrongPass99',
        name: 'Test User',
      );

      final captured = verify(() => dio.post(
            any(),
            data: captureAny(named: 'data'),
          )).captured;
      final data = captured.single as Map<String, dynamic>;
      expect(data.containsKey('email'), isFalse);
    });

    test('includes the email key in the request body when provided',
        () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp({
            'user': validUserJson(),
            'accessToken': 'access-tok',
            'refreshToken': 'refresh-tok',
          }));

      await ds.register(
        phone: '+992900000000',
        password: 'StrongPass99',
        name: 'Test User',
        email: 'user@example.com',
      );

      final captured = verify(() => dio.post(
            any(),
            data: captureAny(named: 'data'),
          )).captured;
      final data = captured.single as Map<String, dynamic>;
      expect(data['email'], 'user@example.com');
    });

    test('throws NetworkException on connection timeout', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenThrow(dioError(type: DioExceptionType.connectionTimeout));

      expect(
        () => ds.register(
          phone: '+992900000000',
          password: 'StrongPass99',
          name: 'Test User',
        ),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('login', () {
    test('returns user + tokens on success', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp({
            'user': validUserJson(),
            'accessToken': 'access-tok',
            'refreshToken': 'refresh-tok',
          }));

      final result = await ds.login(
        phone: '+992900000000',
        password: 'StrongPass99',
      );

      expect(result.user.phone, '+992900000000');
      expect(result.accessToken, 'access-tok');
      expect(result.refreshToken, 'refresh-tok');
    });

    test('posts to the login endpoint with phone/password only', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp({
            'user': validUserJson(),
            'accessToken': 'access-tok',
            'refreshToken': 'refresh-tok',
          }));

      await ds.login(phone: '+992900000000', password: 'StrongPass99');

      final captured = verify(() => dio.post(
            ApiEndpoints.login,
            data: captureAny(named: 'data'),
          )).captured;
      final data = captured.single as Map<String, dynamic>;
      expect(data.keys, containsAll(['phone', 'password']));
      expect(data.length, 2);
    });

    test('throws UnauthorizedException with server message on 401', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenThrow(dioError(
        response: resp({'message': 'Invalid credentials'}, statusCode: 401),
      ));

      await expectLater(
        () => ds.login(phone: '+992900000000', password: 'wrong'),
        throwsA(
          isA<UnauthorizedException>().having(
            (e) => e.message,
            'message',
            'Invalid credentials',
          ),
        ),
      );
    });

    test('joins list-shaped validation messages with a comma', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenThrow(dioError(
        response: resp(
          {
            'message': ['phone must not be empty', 'password too short'],
          },
          statusCode: 400,
        ),
      ));

      await expectLater(
        () => ds.login(phone: '', password: ''),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having(
                (e) => e.message,
                'message',
                'phone must not be empty, password too short',
              ),
        ),
      );
    });

    test('falls back to dio message when response body is not a map',
        () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenThrow(dioError(
        response: resp('plain text error', statusCode: 500),
        message: 'dio-level failure',
      ));

      await expectLater(
        () => ds.login(phone: '+992900000000', password: 'StrongPass99'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', 'dio-level failure'),
        ),
      );
    });

    test('throws NetworkException on connectionError', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenThrow(dioError(type: DioExceptionType.connectionError));

      expect(
        () => ds.login(phone: '+992900000000', password: 'StrongPass99'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws NetworkException on sendTimeout', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenThrow(dioError(type: DioExceptionType.sendTimeout));

      expect(
        () => ds.login(phone: '+992900000000', password: 'StrongPass99'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws NetworkException on receiveTimeout', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenThrow(dioError(type: DioExceptionType.receiveTimeout));

      expect(
        () => ds.login(phone: '+992900000000', password: 'StrongPass99'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('refreshToken', () {
    test('returns fresh access + refresh tokens on success', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp({
            'accessToken': 'new-access',
            'refreshToken': 'new-refresh',
          }));

      final result = await ds.refreshToken('old-refresh-token');

      expect(result.accessToken, 'new-access');
      expect(result.refreshToken, 'new-refresh');
    });

    test('sends the given token in the refreshToken body field', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp({
            'accessToken': 'new-access',
            'refreshToken': 'new-refresh',
          }));

      await ds.refreshToken('old-refresh-token');

      final captured = verify(() => dio.post(
            ApiEndpoints.refresh,
            data: captureAny(named: 'data'),
          )).captured;
      final data = captured.single as Map<String, dynamic>;
      expect(data['refreshToken'], 'old-refresh-token');
    });

    test('throws UnauthorizedException when refresh token is rejected',
        () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenThrow(dioError(
        response: resp({'message': 'Refresh token expired'}, statusCode: 401),
      ));

      expect(
        () => ds.refreshToken('expired-token'),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('logout', () {
    test('completes without error on success', () async {
      when(() => dio.post(any())).thenAnswer((_) async => resp(null));

      await expectLater(ds.logout(), completes);
    });

    test('propagates a ServerException on failure', () async {
      when(() => dio.post(any())).thenThrow(dioError(
        response: resp({'message': 'boom'}, statusCode: 500),
      ));

      expect(() => ds.logout(), throwsA(isA<ServerException>()));
    });
  });

  group('verifyToken', () {
    test('returns the parsed user on success', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp(validUserJson(name: 'Refreshed Name')),
      );

      final user = await ds.verifyToken();

      expect(user.name, 'Refreshed Name');
    });

    test('requests GET /users/me', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp(validUserJson()),
      );

      await ds.verifyToken();

      verify(() => dio.get<dynamic>(ApiEndpoints.userMe)).called(1);
    });

    test('throws UnauthorizedException when token has been revoked',
        () async {
      when(() => dio.get<dynamic>(any())).thenThrow(dioError(
        response: resp({'message': 'Token revoked'}, statusCode: 401),
      ));

      expect(() => ds.verifyToken(), throwsA(isA<UnauthorizedException>()));
    });

    test('maps missing optional fields to null and isActive to true',
        () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'id': 'u9',
          'phone': '+992911111111',
          'name': 'No Extras',
          'createdAt': '2026-02-02T00:00:00.000Z',
        }),
      );

      final user = await ds.verifyToken();

      expect(user.email, isNull);
      expect(user.avatar, isNull);
      expect(user.isActive, isTrue);
    });

    test('respects an explicit isActive:false', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'id': 'u10',
          'phone': '+992911111111',
          'name': 'Deactivated',
          'isActive': false,
          'createdAt': '2026-02-02T00:00:00.000Z',
        }),
      );

      final user = await ds.verifyToken();

      expect(user.isActive, isFalse);
    });

    test('falls back to now() when createdAt is missing, without throwing',
        () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'id': 'u11',
          'phone': '+992911111111',
          'name': 'No CreatedAt',
        }),
      );

      final before = DateTime.now();
      final user = await ds.verifyToken();
      final after = DateTime.now();

      expect(
        user.createdAt.isAfter(before.subtract(const Duration(seconds: 5))),
        isTrue,
      );
      expect(
        user.createdAt.isBefore(after.add(const Duration(seconds: 5))),
        isTrue,
      );
    });

    test('parses a well-formed createdAt into the matching instant',
        () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp(
          validUserJson(createdAt: '2026-03-04T05:06:07.000Z'),
        ),
      );

      final user = await ds.verifyToken();

      expect(user.createdAt, DateTime.parse('2026-03-04T05:06:07.000Z'));
    });
  });

  group('sendOtp', () {
    test('posts phone to the send-otp endpoint', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp(null));

      await ds.sendOtp('+992900000000');

      final captured = verify(() => dio.post(
            ApiEndpoints.sendOtp,
            data: captureAny(named: 'data'),
          )).captured;
      final data = captured.single as Map<String, dynamic>;
      expect(data['phone'], '+992900000000');
    });

    test('throws ServerException when the backend rate-limits the request',
        () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenThrow(dioError(
        response:
            resp({'message': 'Too many requests'}, statusCode: 429),
      ));

      expect(
        () => ds.sendOtp('+992900000000'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 429),
        ),
      );
    });
  });

  group('verifyOtp', () {
    test('returns user + tokens on a correct code', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp({
            'user': validUserJson(),
            'accessToken': 'access-tok',
            'refreshToken': 'refresh-tok',
          }));

      final result = await ds.verifyOtp('+992900000000', '123456');

      expect(result.user.id, 'u1');
      expect(result.accessToken, 'access-tok');
      expect(result.refreshToken, 'refresh-tok');
    });

    test('sends phone and code in the request body', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp({
            'user': validUserJson(),
            'accessToken': 'access-tok',
            'refreshToken': 'refresh-tok',
          }));

      await ds.verifyOtp('+992900000000', '123456');

      final captured = verify(() => dio.post(
            ApiEndpoints.verifyOtp,
            data: captureAny(named: 'data'),
          )).captured;
      final data = captured.single as Map<String, dynamic>;
      expect(data['phone'], '+992900000000');
      expect(data['code'], '123456');
    });

    test('throws ServerException on an invalid/expired code', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenThrow(dioError(
        response: resp({'message': 'Invalid or expired code'},
            statusCode: 400),
      ));

      expect(
        () => ds.verifyOtp('+992900000000', '000000'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });
  });

  group('forgotPassword', () {
    test('posts phone to the forgot-password endpoint', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp(null));

      await ds.forgotPassword('+992900000000');

      final captured = verify(() => dio.post(
            ApiEndpoints.forgotPassword,
            data: captureAny(named: 'data'),
          )).captured;
      final data = captured.single as Map<String, dynamic>;
      expect(data['phone'], '+992900000000');
    });

    test('throws NetworkException when offline', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenThrow(dioError(type: DioExceptionType.connectionError));

      expect(
        () => ds.forgotPassword('+992900000000'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('resetPassword', () {
    test('posts phone, code and newPassword to the reset-password endpoint',
        () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp(null));

      await ds.resetPassword('+992900000000', '123456', 'NewStrongPass1');

      final captured = verify(() => dio.post(
            ApiEndpoints.resetPassword,
            data: captureAny(named: 'data'),
          )).captured;
      final data = captured.single as Map<String, dynamic>;
      expect(data['phone'], '+992900000000');
      expect(data['code'], '123456');
      expect(data['newPassword'], 'NewStrongPass1');
    });

    test('throws ServerException when the code is invalid', () async {
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
          )).thenThrow(dioError(
        response: resp({'message': 'Invalid code'}, statusCode: 400),
      ));

      expect(
        () => ds.resetPassword('+992900000000', 'bad', 'NewStrongPass1'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
