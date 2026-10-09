/// Base class for every failure the API layer can raise.
///
/// Replaces the copy-pasted `try/catch` blocks spread across the ~20 service
/// call sites in `frontend/src/api/`. The React code catches
/// `ApiErrorWithDetails` in each component and inspects `.message` / `.details`;
/// here a single `on ApiException` at the call site covers all of them.
sealed class ApiException implements Exception {
  const ApiException(this.message, {this.details, this.statusCode});

  /// Human-readable summary, safe to show a user.
  final String message;

  /// Extra server context, when present.
  ///
  /// **Careful — this can contain server internals.** On a 500, `Application.kt`
  /// sets `details` to `cause.stackTraceToString()`
  /// (`backend/app/.../Application.kt:69`). Do not render [details] in the UI
  /// without a debug flag; task 9.8/9.9 decide that.
  final String? details;

  /// HTTP status, when the failure came from a response.
  final int? statusCode;

  @override
  String toString() => details == null
      ? '$runtimeType: $message'
      : '$runtimeType: $message\n$details';
}

/// The caller is not authenticated — HTTP 401.
///
/// Signals that the session is gone and the app should return to the login
/// screen. Task 2.2 wires the single-flight redirect; this type is the signal
/// it keys off.
///
/// Note the server also returns 401 from `GET /api/users/context` when the
/// token is missing or unparseable (`UserRoutes.kt:66`), and as a **bare
/// string** from `AuthorizationPlugin.kt:24`, not as an envelope.
class UnauthorizedException extends ApiException {
  const UnauthorizedException({
    String message = 'Unauthorized',
    String? details,
    int statusCode = 401,
  }) : super(message, details: details, statusCode: statusCode);
}

/// A request failed, or succeeded at the HTTP level but not the API level.
///
/// Covers two cases that the React client treats separately:
/// - a non-2xx response carrying the `{success, data, error}` envelope;
/// - a 2xx response whose envelope says `success: false`.
class ApiRequestException extends ApiException {
  const ApiRequestException(super.message, {super.details, super.statusCode});
}

/// The request never produced a usable HTTP response.
///
/// DNS failure, connection refused, CORS rejection, timeout, cancellation.
/// Distinct from [ApiRequestException] because retrying is plausible and
/// because the UI should say "could not reach the server" rather than
/// "the server rejected this".
class NetworkException extends ApiException {
  const NetworkException(super.message, {super.details});
}
