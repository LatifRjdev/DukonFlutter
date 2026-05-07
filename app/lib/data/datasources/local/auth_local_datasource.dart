import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/errors/exceptions.dart';
import '../../../domain/entities/user.dart';

abstract class AuthLocalDatasource {
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });

  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> deleteTokens();

  Future<void> saveUser(User user);
  Future<User?> getUser();
  Future<void> deleteUser();

  Future<bool> hasTokens();

  /// True when the stored access token's JWT `exp` claim is in the past,
  /// or no token is stored, or the token can't be decoded. Caller should
  /// treat any of these as "needs refresh or login".
  Future<bool> isAccessTokenExpired();
}

class AuthLocalDatasourceImpl implements AuthLocalDatasource {
  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userKey = 'cached_user';

  AuthLocalDatasourceImpl({required FlutterSecureStorage storage})
      : _storage = storage;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await Future.wait([
        _storage.write(key: _accessTokenKey, value: accessToken),
        _storage.write(key: _refreshTokenKey, value: refreshToken),
      ]);
    } catch (e) {
      throw CacheException('Failed to save tokens: $e');
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _accessTokenKey);
    } catch (e) {
      throw CacheException('Failed to read access token: $e');
    }
  }

  @override
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } catch (e) {
      throw CacheException('Failed to read refresh token: $e');
    }
  }

  @override
  Future<void> deleteTokens() async {
    try {
      await Future.wait([
        _storage.delete(key: _accessTokenKey),
        _storage.delete(key: _refreshTokenKey),
      ]);
    } catch (e) {
      throw CacheException('Failed to delete tokens: $e');
    }
  }

  @override
  Future<void> saveUser(User user) async {
    try {
      final userJson = jsonEncode({
        'id': user.id,
        'phone': user.phone,
        'name': user.name,
        'email': user.email,
        'avatar': user.avatar,
        'isActive': user.isActive,
        'createdAt': user.createdAt.toIso8601String(),
      });
      await _storage.write(key: _userKey, value: userJson);
    } catch (e) {
      throw CacheException('Failed to save user: $e');
    }
  }

  @override
  Future<User?> getUser() async {
    try {
      final userJson = await _storage.read(key: _userKey);
      if (userJson == null) return null;

      final json = jsonDecode(userJson) as Map<String, dynamic>;
      return User(
        id: json['id'] as String,
        phone: json['phone'] as String,
        name: json['name'] as String,
        email: json['email'] as String?,
        avatar: json['avatar'] as String?,
        isActive: json['isActive'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> deleteUser() async {
    try {
      await _storage.delete(key: _userKey);
    } catch (e) {
      throw CacheException('Failed to delete user: $e');
    }
  }

  @override
  Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<bool> isAccessTokenExpired() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) return true;
    final exp = _decodeJwtExp(token);
    if (exp == null) return true;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowSec >= exp;
  }

  static int? _decodeJwtExp(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }
      final decoded = utf8.decode(base64.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = json['exp'];
      return exp is int ? exp : null;
    } catch (_) {
      return null;
    }
  }
}
