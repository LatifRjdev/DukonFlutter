import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_endpoints.dart';

class ApiInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  final VoidCallback? onSessionExpired;

  ApiInterceptor({
    required FlutterSecureStorage storage,
    this.onSessionExpired,
  }) : _storage = storage;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        // Retry the failed request
        final token = await _storage.read(key: 'access_token');
        err.requestOptions.headers['Authorization'] = 'Bearer $token';
        try {
          final response = await Dio().fetch(err.requestOptions);
          return handler.resolve(response);
        } catch (e) {
          return handler.next(err);
        }
      } else {
        onSessionExpired?.call();
      }
    }
    handler.next(err);
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final dio = Dio();
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _storage.write(key: 'access_token', value: response.data['accessToken']);
        await _storage.write(key: 'refresh_token', value: response.data['refreshToken']);
        return true;
      }
      return false;
    } catch (_) {
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'refresh_token');
      return false;
    }
  }
}
