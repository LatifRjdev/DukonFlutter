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

  /// Destroys the account on the server and wipes what this device cached for
  /// it. Irreversible; required by Google Play for any app with sign-in.
  ///
  /// Unlike [logout], this clears the offline business data too: the server has
  /// deleted the stores and everything in them, so the cached copy is no longer
  /// a cache of anything.
  ///
  /// Throws before touching local state if the server refuses, so a failed
  /// attempt leaves the user signed in with their data intact. Distinguish the
  /// refusals by `ServerException.statusCode`: 403 means the password did not
  /// match, 400 that an owned store still has other active staff.
  Future<void> deleteAccount(String password);

  Future<bool> isAuthenticated();

  Future<String?> getAccessToken();

  Future<User?> getCurrentUser();

  /// Round-trips to the backend (`GET /users/me`) to confirm the cached
  /// access token has not been revoked. Returns the fresh [User] on
  /// success and refreshes the local cache; throws if the server rejects
  /// the token (e.g. password changed elsewhere). Used by the app
  /// lifecycle observer to detect server-side token revocation when the
  /// app is brought back to the foreground.
  Future<User> verifyToken();

  Future<void> sendOtp(String phone);

  Future<({User user, String accessToken, String refreshToken})> verifyOtp(
    String phone,
    String code,
  );

  Future<void> forgotPassword(String phone);

  Future<void> resetPassword(String phone, String code, String newPassword);
}
