import 'package:flutter/foundation.dart';

/// Build-time configuration for the Teven API client.
///
/// The asymmetry below is deliberate and load-bearing.
///
/// **Web** is served from the same origin as the API: the Ktor backend bundles
/// this app's build output into its static resources and serves it at `/`
/// (`backend/app/.../app/Routing.kt`, `staticResources("/", "static")`).
/// Relative URLs therefore resolve correctly with no configuration, and no CORS
/// preflight is needed.
///
/// **Native** has no origin to be relative to, so it needs an absolute base URL
/// supplied at build time:
///
/// ```
/// flutter build apk --dart-define=API_BASE_URL=https://example.com
/// ```
///
/// Native packaging is deferred to Phase 11 of FLUTTER-CONVERT.md; this class
/// exists now so the web path is wired correctly from the start.
class ApiConfig {
  const ApiConfig._();

  /// Supplied via `--dart-define=API_BASE_URL=...`.
  ///
  /// Empty on web, where relative URLs are correct.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Base URL for API requests. Empty string means "same origin".
  static String get baseUrl => apiBaseUrl;

  /// True when running in a browser.
  static bool get isWeb => kIsWeb;

  /// Resolves [path] against [baseUrl].
  ///
  /// With an empty [baseUrl] this returns [path] unchanged, which `dio` then
  /// resolves against the document origin.
  static String resolve(String path) {
    if (baseUrl.isEmpty) {
      return path;
    }
    return '${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path';
  }
}
