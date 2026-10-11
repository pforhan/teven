import '../../models/user.dart';
import '../api/api_client.dart';
import '../api/token_store.dart';

/// Login, logout, and the current user's identity.
///
/// Replaces `AuthService` in `frontend/src/api/AuthService.ts`.
///
/// Token storage is injected as [TokenStore] rather than reached for
/// statically, so [login] can persist the token without this class depending
/// on a plugin.
class AuthService {
  const AuthService(this._client, this._tokenStore);

  final ApiClient _client;
  final TokenStore _tokenStore;

  /// Authenticates and persists the returned token.
  ///
  /// **The token is stored before returning**, unlike the React version, which
  /// sets `localStorage` only when `data.token` is truthy but still resolves.
  /// Same effect in practice; doing it here keeps the ordering explicit.
  ///
  /// Throws [UnauthorizedException] on bad credentials — the server answers
  /// `failure("Invalid username or password")` with 401
  /// (`AuthRoutes.kt`). Task 2.9's login screen renders `message`.
  ///
  /// Persisting the token can itself throw when `window.isSecureContext` is
  /// false. That is deliberately **not** swallowed: reporting a successful
  /// login that was not persisted would strand the user on a session that dies
  /// at the next request. See `TokenStore`.
  Future<LoginResponse> login({
    required String username,
    required String password,
  }) async {
    final response = await _client.post<LoginResponse>(
      '/api/users/login',
      request: LoginRequest(username: username, password: password),
      decode: (json) => LoginResponse.fromJson(json! as Map<String, dynamic>),
    );
    await _tokenStore.write(response.token);
    return response;
  }

  /// Drops the stored token.
  Future<void> logout() => _tokenStore.clear();

  /// The stored token, or `null`.
  ///
  /// Async because the underlying store is. `ApiClient` reads this
  /// internally on every request, so most call sites never need it directly.
  Future<String?> getToken() => _tokenStore.read();

  /// The user plus their permissions in the currently selected organization.
  ///
  /// The gating source for the whole UI. Throws
  /// [UnauthorizedException] if the token is missing or expired, which is what
  /// drives task 2.2's redirect.
  Future<UserContextResponse> getUserContext() =>
      _client.get<UserContextResponse>(
        '/api/users/context',
        decode: (json) =>
            UserContextResponse.fromJson(json! as Map<String, dynamic>),
      );

  /// A single user, including staff details when they have them.
  ///
  /// Returns the same [UserResponse] shape the list and create endpoints use —
  /// the React `UserDetailsResponse` was a near-duplicate lacking
  /// `organization`, and is not reproduced.
  Future<UserResponse> getUser(int userId) => _client.get<UserResponse>(
    '/api/users/$userId',
    decode: (json) => UserResponse.fromJson(json! as Map<String, dynamic>),
  );

  /// Updates a user and returns the updated record.
  Future<UserResponse> updateUser(int userId, UpdateUserRequest request) =>
      _client.put<UserResponse>(
        '/api/users/$userId',
        request: request,
        decode: (json) => UserResponse.fromJson(json! as Map<String, dynamic>),
      );
}
