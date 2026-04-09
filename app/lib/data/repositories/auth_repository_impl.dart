import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local/auth_local_datasource.dart';
import '../datasources/remote/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _remoteDatasource;
  final AuthLocalDatasource _localDatasource;

  AuthRepositoryImpl({
    required AuthRemoteDatasource remoteDatasource,
    required AuthLocalDatasource localDatasource,
  })  : _remoteDatasource = remoteDatasource,
        _localDatasource = localDatasource;

  @override
  Future<({User user, String accessToken, String refreshToken})> register({
    required String phone,
    required String password,
    required String name,
    String? email,
  }) async {
    final result = await _remoteDatasource.register(
      phone: phone,
      password: password,
      name: name,
      email: email,
    );

    await _localDatasource.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    await _localDatasource.saveUser(result.user);

    return result;
  }

  @override
  Future<({User user, String accessToken, String refreshToken})> login({
    required String phone,
    required String password,
  }) async {
    final result = await _remoteDatasource.login(
      phone: phone,
      password: password,
    );

    await _localDatasource.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    await _localDatasource.saveUser(result.user);

    return result;
  }

  @override
  Future<({String accessToken, String refreshToken})> refreshToken(
    String token,
  ) async {
    final result = await _remoteDatasource.refreshToken(token);

    await _localDatasource.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );

    return result;
  }

  @override
  Future<void> logout() async {
    try {
      await _remoteDatasource.logout();
    } catch (_) {
      // Ignore remote logout errors; always clear local state.
    }
    await _localDatasource.deleteTokens();
    await _localDatasource.deleteUser();
  }

  @override
  Future<bool> isAuthenticated() async {
    return await _localDatasource.hasTokens();
  }

  @override
  Future<String?> getAccessToken() async {
    return await _localDatasource.getAccessToken();
  }

  @override
  Future<User?> getCurrentUser() async {
    return await _localDatasource.getUser();
  }
}
