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
/// deliberately out of scope for the port; see FLUTTER-CONVERT.md under "The
/// one deployment consideration".
///
/// Note the current React behaviour is weaker: a token in `localStorage` is
/// readable by any script on the origin.
class TokenStore {
  const TokenStore(this._storage);

  /// Storage key.
  ///
  /// Matches the React `TOKEN_KEY` for continuity, but see the class doc:
  /// the stored value is encrypted and namespaced, so the token does **not**
  /// carry over.
  static const String storageKey = 'teven-auth-token';

  final FlutterSecureStorage _storage;

  /// The token, or `null` when absent **or when the store is unavailable**.
  ///
  /// Swallowing the error is deliberate for reads only: a boot-time read
  /// failure should degrade to "logged out", not crash the app before it can
  /// render a login screen.
  Future<String?> read() async {
    try {
      return await _storage.read(key: storageKey);
    } catch (_) {
      return null;
    }
  }

  /// Stores [token], replacing any existing one.
  ///
  /// **Propagates failure.** A login must not appear to succeed if the token
  /// was not persisted.
  Future<void> write(String token) =>
      _storage.write(key: storageKey, value: token);

  /// Clears the token. Called on logout and on an unauthorized response.
  ///
  /// Swallows errors: clearing is best-effort, and failing to clear a token
  /// should not prevent the user from reaching the login screen.
  Future<void> clear() async {
    try {
      await _storage.delete(key: storageKey);
    } catch (_) {
      // Best-effort.
    }
  }
}
