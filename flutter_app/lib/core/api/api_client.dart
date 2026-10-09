import 'dart:convert';

import 'package:dio/dio.dart';

import '../../models/api_response.dart';
import '../config/api_config.dart';
import 'api_exception.dart';
import 'token_store.dart';

/// How a response body should be interpreted.
enum ResponseBody {
  /// Expect the standard `{success, data, error}` envelope.
  envelope,

  /// Expect no body at all — a `204 No Content`.
  ///
  /// Deletes answer this way (`CustomerRoutes.kt:72`, `InventoryRoutes.kt:71`,
  /// `EventRoutes.kt:63`), so `data` is genuinely absent rather than null.
  empty,

  /// The body is a bare JSON **string**, not an object.
  ///
  /// `AuthorizationPlugin.kt:24,31` responds with a plain string such as
  /// `"User does not have the required permission"`, bypassing the envelope
  /// entirely. Several `success(...)` calls do the same — `PUT /api/events/{id}`
  /// returns `"Event with ID N updated"` (`EventRoutes.kt:71`).
  bareString,

  /// Do not inspect the body; pass it through as decoded JSON.
  raw,
}

/// The single HTTP entry point.
///
/// Replaces `apiClient` in `frontend/src/api/apiClient.ts` and its ~20
/// call-site `try/catch` blocks, which are consolidated into the
/// [ApiException] hierarchy instead of being ported.
class ApiClient {
  ApiClient(this._tokenStore, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              // Every non-2xx is handled below, so let them through rather
              // than having dio throw first — the envelope inside a 400
              // carries the message, and that is worth surfacing.
              validateStatus: (_) => true,
            ),
          );

  final Dio _dio;
  final TokenStore _tokenStore;

  /// Fetches [path] and returns the unwrapped `data`.
  ///
  /// [decode] converts the raw `data` field into `T`; it is only invoked when
  /// the response is a success with a non-null `data`.
  Future<T> get<T>(
    String path, {
    required T Function(Object? json) decode,
    Map<String, dynamic>? query,
    ResponseBody body = ResponseBody.envelope,
    CancelToken? cancelToken,
  }) async {
    final response = await _send(
      path,
      method: 'GET',
      query: query,
      body: body,
      cancelToken: cancelToken,
    );
    return _unwrap<T>(response, decode);
  }

  /// POSTs [request] as JSON and returns the unwrapped `data`.
  Future<T> post<T>(
    String path, {
    Object? request,
    required T Function(Object? json) decode,
    Map<String, dynamic>? query,
    ResponseBody body = ResponseBody.envelope,
    CancelToken? cancelToken,
  }) async {
    final response = await _send(
      path,
      method: 'POST',
      query: query,
      body: body,
      request: request,
      cancelToken: cancelToken,
    );
    return _unwrap<T>(response, decode);
  }

  /// PUTs [request] as JSON and returns the unwrapped `data`.
  Future<T> put<T>(
    String path, {
    Object? request,
    required T Function(Object? json) decode,
    ResponseBody body = ResponseBody.envelope,
    CancelToken? cancelToken,
  }) async {
    final response = await _send(
      path,
      method: 'PUT',
      body: body,
      request: request,
      cancelToken: cancelToken,
    );
    return _unwrap<T>(response, decode);
  }

  /// DELETEs [path].
  ///
  /// Returns `null` on success, since a delete answers `204` with no body.
  /// Use [deleteWithBody] for the rare endpoint that returns a payload.
  Future<void> delete(String path, {CancelToken? cancelToken}) async {
    await _send(path, method: 'DELETE', cancelToken: cancelToken);
  }

  /// DELETEs [path] and decodes a response body.
  ///
  /// `DELETE /api/inventory/{id}/usage` and similar return `success("OK")`
  /// rather than `204`.
  Future<T> deleteWithBody<T>(
    String path, {
    required T Function(Object? json) decode,
    ResponseBody body = ResponseBody.bareString,
    CancelToken? cancelToken,
  }) async {
    final response = await _send(
      path,
      method: 'DELETE',
      body: body,
      cancelToken: cancelToken,
    );
    return _unwrap<T>(response, decode);
  }

  /// Issues the request, attaching auth and normalizing transport failures.
  Future<Response<dynamic>> _send(
    String path, {
    required String method,
    Map<String, dynamic>? query,
    Object? request,
    ResponseBody body = ResponseBody.envelope,
    CancelToken? cancelToken,
  }) async {
    final token = await _tokenStore.read();

    try {
      final response = await _dio.request<dynamic>(
        ApiConfig.resolve(path),
        data: request,
        queryParameters: query,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          // Never let dio decode. Content negotiation and JSON parsing both
          // happen in _tryDecode instead, because only this class knows how to
          // distinguish an envelope from a bare JSON string from index.html —
          // and dio's own parsing makes those cases indistinguishable, since
          // a JSON string body already arrives as a Dart String.
          responseType: ResponseType.plain,
          // Set per-request rather than only on BaseOptions, so it holds even
          // when a caller injects a preconfigured Dio. Every non-2xx is
          // interpreted below, because the useful message is in the envelope
          // body rather than the status line.
          validateStatus: (_) => true,
        ),
      );

      // A non-2xx still needs interpreting: the failure message lives in the
      // envelope body, not the status line.
      final status = response.statusCode ?? 0;
      if (status >= 400) {
        throw _errorFor(response, status);
      }

      return response;
    } on DioException catch (error) {
      // A response that got as far as arriving is handled above; anything
      // reaching here never produced one. `error.response` is still checked
      // defensively, so an injected Dio with stricter validateStatus still
      // yields the server's message instead of a generic network error.
      final response = error.response;
      if (response != null) {
        throw _errorFor(response, response.statusCode ?? 0);
      }
      if (CancelToken.isCancel(error)) {
        throw NetworkException('Request cancelled', details: error.message);
      }
      throw NetworkException(
        'Could not reach the server',
        details: error.message ?? error.toString(),
      );
    }
  }

  /// Builds the right exception for a non-2xx [response].
  ApiException _errorFor(Response<dynamic> response, int status) {
    final decoded = _tryDecode(response);

    if (decoded is _NonJsonBody) {
      return _notAnEnvelope(decoded, status);
    }

    if (decoded is Map<String, dynamic>) {
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final apiError = ApiError.fromJson(error);
        // 401 becomes UnauthorizedException even when it arrives inside an
        // envelope, so the redirect logic has one type to match on.
        if (status == 401) {
          return UnauthorizedException(
            message: apiError.message,
            details: apiError.details,
            statusCode: status,
          );
        }
        return ApiRequestException(
          apiError.message,
          details: apiError.details,
          statusCode: status,
        );
      }
    }

    // Bare string from AuthorizationPlugin.kt, or unparseable.
    if (decoded is String) {
      if (status == 401) {
        return UnauthorizedException(message: decoded, statusCode: status);
      }
      return ApiRequestException(decoded, statusCode: status);
    }

    final message = status == 401
        ? 'Session expired. Please log in again.'
        : 'API request failed with status $status';
    if (status == 401) {
      return UnauthorizedException(message: message, statusCode: status);
    }
    return ApiRequestException(
      message,
      details: response.data?.toString(),
      statusCode: status,
    );
  }

  /// Unwraps a 2xx response into `T`, or throws.
  T _unwrap<T>(Response<dynamic> response, T Function(Object? json) decode) {
    final decoded = _tryDecode(response);
    final status = response.statusCode ?? 0;

    // Non-JSON body on a 2xx — the SPA fallback, not an API response.
    if (decoded is _NonJsonBody) {
      throw _notAnEnvelope(decoded, status);
    }

    // 204, or any genuinely empty body.
    if (decoded == null) {
      throw ApiRequestException(
        'API request failed: expected a response body but got none',
        statusCode: status,
      );
    }

    if (decoded is Map<String, dynamic> && decoded.containsKey('success')) {
      final envelope = ApiResponse.fromJson(decoded, decode);
      if (!envelope.success) {
        throw ApiRequestException(
          envelope.error?.message ?? 'API request failed',
          details: envelope.error?.details,
          statusCode: status,
        );
      }
      final data = envelope.data;
      if (data == null) {
        throw ApiRequestException(
          'API request succeeded but returned no data',
          statusCode: status,
        );
      }
      return data;
    }

    // Not an envelope. A bare string is legitimate for several endpoints, but a
    // JSON *object* that is not an envelope means the request fell through to
    // the SPA handler and we were served index.html.
    //
    // `apiClient.ts:44` sniffs content-type for the same reason. Here the
    // check is structural, which is stronger: index.html decodes as a String,
    // so it would be misread as a bare-string body.
    if (decoded is Map || decoded is List) {
      throw ApiRequestException(
        'Received an unexpected response that was not an API envelope. '
        'This usually means the route does not exist and the web app was '
        'served instead.',
        details: jsonEncode(decoded),
        statusCode: status,
      );
    }

    // A bare string, or a scalar.
    return decode(decoded);
  }

  /// Decodes the body without throwing.
  ///
  /// Always receives raw text (`ResponseType.plain`), so an empty body is
  /// unambiguous — there is no already-decoded value to confuse it with.
  Object? _tryDecode(Response<dynamic> response) {
    final data = response.data;
    if (data == null) {
      return null;
    }
    if (data is! String) {
      // Defensive: should be unreachable given ResponseType.plain, but if a
      // caller injects a Dio that overrides it, do not mangle the value.
      return data;
    }
    if (data.isEmpty) {
      return null;
    }

    // Task 1.12: never treat a non-JSON 200 as success.
    //
    // A request to an unmatched route with a verb other than
    // GET/POST/PUT/DELETE falls through to the SPA handler and comes back as
    // `index.html` with HTTP 200 (`Routing.kt:56`). That is not valid JSON,
    // so without this check `jsonDecode` would throw, be swallowed by the
    // `catch` below, and the raw HTML would be handed back as if it were a
    // legitimate bare-string body — a silent success carrying a web page.
    //
    // Sniffing the content type catches it at the source. This mirrors
    // `apiClient.ts:44`, which checks the header before calling `.json()`.
    final contentType = response.headers.value(Headers.contentTypeHeader);
    if (contentType != null && !_isJson(contentType)) {
      return _NonJsonBody(data, contentType: contentType);
    }

    try {
      return jsonDecode(data) as Object?;
    } on FormatException {
      // Header claimed JSON but the body did not parse. Hand the text back so
      // the caller can report it, tagged so it is not mistaken for a
      // bare-string API response.
      return _NonJsonBody(data, contentType: contentType);
    }
  }

  /// The request reached the SPA handler instead of the API.
  ///
  /// Covers both the HTTP-200 `index.html` case (task 1.12) and a non-JSON
  /// error page.
  ApiException _notAnEnvelope(_NonJsonBody body, int status) {
    if (status == 401) {
      return UnauthorizedException(
        message: 'Session expired. Please log in again.',
        statusCode: status,
      );
    }
    return ApiRequestException(
      'The server did not return an API response. '
      'This usually means the route does not exist and the web app was '
      'served instead.',
      details: 'content-type: ${body.contentType}',
      statusCode: status,
    );
  }

  static bool _isJson(String contentType) {
    final mime = contentType.split(';').first.trim().toLowerCase();
    return mime == 'application/json' || mime.endsWith('+json');
  }
}

/// A body that is not JSON, tagged so it cannot be mistaken for a legitimate
/// bare-string API response.
///
/// The important case is `index.html` served with HTTP 200 for an unmatched
/// route (see [_tryDecode]). Without the tag it would be indistinguishable
/// from the bare strings that `AuthorizationPlugin.kt` genuinely returns.
class _NonJsonBody {
  const _NonJsonBody(this.text, {this.contentType});

  final String text;
  final String? contentType;

  @override
  String toString() => text;
}
