import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Reads and writes the auth token.
///
/// Replaces `localStorage`, which the React `AuthService` uses
/// (`frontend/src/api/AuthService.ts:3`).
///
/// **Storage format is encrypted, not plaintext.** The web implementation
/// namespaces keys as `publicKey.<key>` and stores AES-GCM ciphertext
/// (`flutter_secure_storage_web-2.1.1/lib/flutter_secure_storage_web.dart:50`).
/// So this store does not share state with the React app's plaintext
/// `localStorage` — irrelevant today, since the app has no users yet and there
/// is nothing to migrate. Noted only so nobody later assumes an existing
/// session carries over.
///
/// **TLS caveat — read failures degrade, write failures do not.** The web
/// backend throws `UnsupportedError` when `window.isSecureContext` is false,
/// and it checks on *every* operation rather than once at init
/// (`flutter_secure_storage_web.dart:26`). So:
///
/// - reads are caught below and return `null`, degrading to "logged out";
/// - writes throw, and there is no safe place to swallow that — a login that
///   reports success while failing to persist the token would strand the user
///   on a session that dies at the next request.
///
/// The container is served over **plain HTTP** on port 2022
/// (`docker-compose.yml:25`). `http://localhost` is a secure context, so all
/// local verification works. Reached from another machine it is neither HTTPS
/// nor localhost, and **login breaks outright** — not quietly degrades. The fix
/// is TLS termination in front of the container, or a `shared_preferences`
/// fallback keyed off `isSecureContext`. Both are deployment concerns,
/// deliberately out of scope for the port; see FLUTTER-CONVERT-DESIGN.md under
/// "The one deployment consideration".
///
/// Note the current React behaviour is weaker: a token in `localStorage` is
/// readable by any script on the origin.
class TokenStore {
  const TokenStore(this._storage);

  /// The real store, backed by `flutter_secure_storage`.
  const TokenStore.secure() : this(const _SecureTokenStorage());

  /// A process-local store, for tests.
  ///
  /// The plugin reaches a platform channel that a widget test has no answer
  /// for: reads throw (and would be swallowed into "logged out") while writes
  /// throw outright. A test could therefore never arrange a signed-in user.
  @visibleForTesting
  factory TokenStore.inMemory({String? token}) =>
      TokenStore(_MemoryTokenStorage(token));

  static const String storageKey = 'teven-auth-token';

  final TokenStorage _storage;

  /// The token, or `null` when absent **or when the store is unavailable**.
  ///
  /// Swallowing the error is deliberate for reads only: a boot-time read
  /// failure should degrade to "logged out", not crash the app before it can
  /// render a login screen.
  Future<String?> read() async {
    try {
      return await _storage.read();
    } catch (_) {
      return null;
    }
  }

  /// Stores [token], replacing any existing one.
  ///
  /// **Propagates failure.** A login must not appear to succeed if the token
  /// was not persisted.
  Future<void> write(String token) => _storage.write(token);

  /// Clears the token. Called on logout and on an unauthorized response.
  ///
  /// Swallows errors: clearing is best-effort, and failing to clear a token
  /// should not prevent the user from reaching the login screen.
  Future<void> clear() async {
    try {
      await _storage.clear();
    } catch (_) {
      // Best-effort.
    }
  }
}

/// Where a token actually lives.
///
/// Narrower than [FlutterSecureStorage] on purpose. The plugin's own interface
/// carries per-platform option objects on every method, so mirroring it means
/// re-declaring its signature against a version we do not control — and a
/// `FlutterSecureStorage` stand-in has to implement all eighteen methods to
/// satisfy `implements`. Three methods keyed by nothing but the token is all
/// this app needs.
abstract interface class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// The production backend. See [TokenStore] for the TLS caveat, which is why
/// reads degrade and writes propagate.
class _SecureTokenStorage implements TokenStorage {
  const _SecureTokenStorage();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: TokenStore.storageKey);

  @override
  Future<void> write(String token) =>
      _storage.write(key: TokenStore.storageKey, value: token);

  @override
  Future<void> clear() => _storage.delete(key: TokenStore.storageKey);
}

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage(this._token);

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
