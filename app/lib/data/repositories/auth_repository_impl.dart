import 'package:sqflite/sqflite.dart';

import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local/auth_local_datasource.dart';
import '../datasources/local/cart_local_datasource.dart';
import '../datasources/remote/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _remoteDatasource;
  final AuthLocalDatasource _localDatasource;

  /// Only [deleteAccount] uses these two: an account that no longer exists on
  /// the server must not leave its products, sales and cart behind on the
  /// device. Ordinary logout deliberately keeps them.
  final Database _database;
  final CartLocalDatasource _cart;

  AuthRepositoryImpl({
    required AuthRemoteDatasource remoteDatasource,
    required AuthLocalDatasource localDatasource,
    required Database database,
    required CartLocalDatasource cart,
  })  : _remoteDatasource = remoteDatasource,
        _localDatasource = localDatasource,
        _database = database,
        _cart = cart;

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
  Future<void> deleteAccount(String password) async {
    // Deliberately NOT wrapped in a catch, unlike logout. Logout can ignore a
    // server error because the local session is the thing being ended either
    // way. Here the server is the only thing that can actually delete the
    // account, so if it refuses — wrong password, staff still in a store — the
    // user has to stay signed in with everything intact and see why.
    await _remoteDatasource.deleteAccount(password);

    // Past this point the account is gone server-side, so every step below is
    // best-effort cleanup: failing here must not leave the user staring at an
    // error for an account that no longer exists.
    try {
      // The live schema is created in injection.dart's _initDatabase: products,
      // sales, categories and the sync queue. Read from sqlite_master rather
      // than hardcoded, because a hardcoded list silently stops covering any
      // table added later and the failure mode is a deleted account's business
      // data sitting on the device, which nothing fails loudly about.
      final tables = await _database.query(
        'sqlite_master',
        columns: ['name'],
        where: "type = 'table' AND name NOT LIKE 'sqlite_%' "
            "AND name NOT LIKE 'android_%'",
      );
      final batch = _database.batch();
      for (final row in tables) {
        batch.execute('DELETE FROM "${row['name'] as String}"');
      }
      await batch.commit(noResult: true);
    } catch (_) {
      // A wipe that fails is bad but not worth blocking sign-out over.
    }
    try {
      await _cart.clear();
    } catch (_) {
      // Same.
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

  @override
  Future<User> verifyToken() async {
    final user = await _remoteDatasource.verifyToken();
    // Refresh the cached user so any stale profile data (name, email,
    // avatar) reflects what the server says after a successful round-trip.
    await _localDatasource.saveUser(user);
    return user;
  }

  @override
  Future<void> sendOtp(String phone) async {
    await _remoteDatasource.sendOtp(phone);
  }

  @override
  Future<({User user, String accessToken, String refreshToken})> verifyOtp(
    String phone,
    String code,
  ) async {
    final result = await _remoteDatasource.verifyOtp(phone, code);

    await _localDatasource.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    await _localDatasource.saveUser(result.user);

    return result;
  }

  @override
  Future<void> forgotPassword(String phone) async {
    await _remoteDatasource.forgotPassword(phone);
  }

  @override
  Future<void> resetPassword(
    String phone,
    String code,
    String newPassword,
  ) async {
    await _remoteDatasource.resetPassword(phone, code, newPassword);
  }
}
