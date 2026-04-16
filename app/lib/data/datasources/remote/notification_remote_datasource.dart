import 'package:dio/dio.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/dio_client.dart';

abstract class NotificationRemoteDatasource {
  Future<({List<Map<String, dynamic>> data, int total})> getNotifications(
    String storeId, {
    int page = 1,
    int limit = 20,
  });

  Future<void> markAsRead(String storeId, String notificationId);

  Future<Map<String, dynamic>> getSettings(String storeId);

  Future<void> saveSettings(String storeId, Map<String, dynamic> settings);

  Future<void> saveFcmToken(String token, {String? platform});
}

class NotificationRemoteDatasourceImpl implements NotificationRemoteDatasource {
  final DioClient _dioClient;

  NotificationRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<({List<Map<String, dynamic>> data, int total})> getNotifications(
    String storeId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dioClient.get(
        '/stores/$storeId/notifications',
        queryParameters: {'page': page, 'limit': limit},
      );

      final responseData = response.data as Map<String, dynamic>;
      final items = (responseData['data'] as List? ??
              responseData['items'] as List? ??
              [])
          .cast<Map<String, dynamic>>();

      return (
        data: items,
        total: responseData['total'] as int? ?? items.length,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> markAsRead(String storeId, String notificationId) async {
    try {
      await _dioClient.put('/stores/$storeId/notifications/$notificationId/read');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getSettings(String storeId) async {
    try {
      final response =
          await _dioClient.get('/stores/$storeId/notifications/settings');
      return response.data as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> saveSettings(
      String storeId, Map<String, dynamic> settings) async {
    try {
      await _dioClient.put(
        '/stores/$storeId/notifications/settings',
        data: settings,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> saveFcmToken(String token, {String? platform}) async {
    try {
      await _dioClient.post(
        '/users/me/fcm-token',
        data: {
          'token': token,
          if (platform != null) 'platform': platform,
        },
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const NetworkException();
    }

    final statusCode = e.response?.statusCode;
    final rawMessage =
        (e.response?.data is Map) ? e.response?.data['message'] : null;
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
