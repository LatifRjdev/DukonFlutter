import '../entities/user.dart';

abstract class AuthRepository {
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

  Future<({String accessToken, String refreshToken})> refreshToken(String refreshToken);

  Future<void> logout();

  Future<bool> isAuthenticated();

  Future<String?> getAccessToken();

  Future<User?> getCurrentUser();
}
