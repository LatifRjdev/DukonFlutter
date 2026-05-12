import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/user.dart';

abstract class AuthRemoteDatasource {
  Future<({User user, String accessToken, String refreshToken})> register({
    required String phone,
    required String password,
    required String name,
    String? email,
  });

  Future<({User user, String accessToken, String refreshToken})> login({
    required String phone,
    required String password,
  });

  Future<({String accessToken, String refreshToken})> refreshToken(
    String refreshToken,
  );

  Future<void> logout();

  /// Hits `GET /users/me` against the backend with the current access token
  /// to confirm the session is still valid. Returns the up-to-date [User]
  /// payload on success; throws [UnauthorizedException] if the server says
  /// the token has been revoked (e.g. after a server-side password change
  /// bumped `tokensRevokedAt`).
  Future<User> verifyToken();

  Future<void> sendOtp(String phone);

  Future<({User user, String accessToken, String refreshToken})> verifyOtp(
    String phone,
    String code,
  );

  Future<void> forgotPassword(String phone);

  Future<void> resetPassword(String phone, String code, String newPassword);
}

class AuthRemoteDatasourceImpl implements AuthRemoteDatasource {
  final DioClient _dioClient;

  AuthRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<({User user, String accessToken, String refreshToken})> register({
    required String phone,
    required String password,
    required String name,
    String? email,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.register,
        data: {
          'phone': phone,
          'password': password,
          'name': name,
          'email': ?email,
        },
      );

      final data = response.data as Map<String, dynamic>;
      return (
        user: _mapUser(data['user'] as Map<String, dynamic>),
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<({User user, String accessToken, String refreshToken})> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.login,
        data: {
          'phone': phone,
          'password': password,
        },
      );

      final data = response.data as Map<String, dynamic>;
      return (
        user: _mapUser(data['user'] as Map<String, dynamic>),
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<({String accessToken, String refreshToken})> refreshToken(
    String token,
  ) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': token},
      );

      final data = response.data as Map<String, dynamic>;
      return (
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _dioClient.post(ApiEndpoints.logout);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<User> verifyToken() async {
    try {
      final response = await _dioClient.get(ApiEndpoints.userMe);
      return _mapUser(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> sendOtp(String phone) async {
    try {
      await _dioClient.post(
        ApiEndpoints.sendOtp,
        data: {'phone': phone},
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<({User user, String accessToken, String refreshToken})> verifyOtp(
    String phone,
    String code,
  ) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.verifyOtp,
        data: {'phone': phone, 'code': code},
      );

      final data = response.data as Map<String, dynamic>;
      return (
        user: _mapUser(data['user'] as Map<String, dynamic>),
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> forgotPassword(String phone) async {
    try {
      await _dioClient.post(
        ApiEndpoints.forgotPassword,
        data: {'phone': phone},
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> resetPassword(
    String phone,
    String code,
    String newPassword,
  ) async {
    try {
      await _dioClient.post(
        ApiEndpoints.resetPassword,
        data: {
          'phone': phone,
          'code': code,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  User _mapUser(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      avatar: json['avatar'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Exception _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const NetworkException();
    }

    final statusCode = e.response?.statusCode;
    final rawMessage = (e.response?.data is Map) ? e.response?.data['message'] : null;
    final String message;
    if (rawMessage is List) {
      message = rawMessage.join(', ');
    } else if (rawMessage is String) {
      message = rawMessage;
    } else {
      message = e.message ?? 'Unknown error';
    }

    if (statusCode == 401) {
      return UnauthorizedException(message);
    }

    return ServerException(message, statusCode: statusCode);
  }
}
