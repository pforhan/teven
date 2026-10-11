import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A canned HTTP response, independent of any transport.
class StubResponse {
  const StubResponse.json(
    this.body, {
    this.status = 200,
    this.contentType = 'application/json; charset=utf-8',
  }) : isEmpty = false;

  /// A `204 No Content` — no body at all.
  const StubResponse.noContent()
    : body = '',
      status = 204,
      contentType = null,
      isEmpty = true;

  /// A body that is not JSON, e.g. the SPA fallback serving `index.html`.
  const StubResponse.html(this.body)
    : status = 200,
      contentType = 'text/html; charset=utf-8',
      isEmpty = false;

  final String body;
  final int status;
  final String? contentType;
  final bool isEmpty;
}

/// A [Dio] transport that returns canned responses instead of making requests.
///
/// Used **above** the parsing layer — service and screen tests. [FakeApiServer]
/// in `fake_api_server.dart` is the real-socket counterpart and is reserved for
/// tests that are actually about parsing HTTP: content-type sniffing, empty
/// bodies, connection failures. Anything that merely needs a response body to
/// read should use this instead, so it runs identically on the VM and on web
/// (`dart:io` sockets do not exist in the browser).
class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.handler);

  /// Supplies the response for a request. Returning `null` yields a 404
  /// envelope, mirroring the server's `/api` catch-all.
  StubResponse Function(RequestOptions options)? handler;

  /// Every request made, in order.
  final List<RequestOptions> requests = [];

  RequestOptions get last => requests.last;

  /// Query parameters of the most recent request, flattened.
  Map<String, dynamic> get lastQuery => last.queryParameters;

  /// Decoded JSON body of the most recent request.
  Object? lastRequestBody;

  /// Reads a request body off [requestStream] as text.
  static Future<String?> _decode(Stream<Uint8List>? stream) async {
    if (stream == null) {
      return null;
    }
    final bytes = await stream.expand((c) => c).toList();
    if (bytes.isEmpty) {
      return null;
    }
    return utf8.decode(bytes);
  }

  /// Body of the most recent request, as JSON text.
  ///
  /// dio's transformer runs before the adapter, so an object body arrives
  /// already encoded as a JSON string.
  String? get lastBody {
    final data = last.data;
    return data is String ? data : null;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    lastRequestBody = await _decode(requestStream);
    final response = handler?.call(options);

    if (response == null) {
      return _body(
        '{"success":false,"data":{},'
        '"error":{"message":"API endpoint not found"}}',
        404,
      );
    }
    if (response.isEmpty) {
      return _body('', response.status, contentType: null);
    }
    return _body(
      response.body,
      response.status,
      contentType: response.contentType,
    );
  }

  static ResponseBody _body(String text, int status, {String? contentType}) =>
      ResponseBody.fromString(
        text,
        status,
        headers: {
          if (contentType != null) 'content-type': [contentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// A [Dio] wired to [adapter], with response decoding left to `ApiClient`.
///
/// `responseType` stays `plain` so the client under test owns all parsing —
/// matching what `ApiClient` does in production.
Dio stubDio(StubAdapter adapter) => Dio()..httpClientAdapter = adapter;

/// A [Dio] that answers every request with [response].
Dio stubDioReturning(StubResponse response) =>
    Dio()..httpClientAdapter = StubAdapter((_) => response);
