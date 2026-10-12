import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:teven_app/core/api/api_client.dart';
import 'package:teven_app/core/api/token_store.dart';

/// A real HTTP server that replays the Teven backend's actual response shapes.
///
/// Tests here bind a real socket and point a real [Dio] at it rather than
/// mocking the transport. That matters because the behaviour under test
/// *is* the transport's: whether a body is JSON, what `content-type` says, and
/// what an empty 204 looks like to dio. A mocked adapter would assert our own
/// assumptions rather than the ones the client actually has to survive.
class FakeApiServer {
  FakeApiServer._(this._server);

  final HttpServer _server;

  /// Every request path received, in order.
  final List<String> requests = [];

  /// Query string of the most recent request.
  String? lastQuery;

  /// Body of the most recent request.
  String? lastBody;

  /// HTTP method of the most recent request.
  String? lastMethod;

  /// Supplies a response for a request path.
  ///
  /// Returning `null` falls through to a 404 envelope, matching the server's
  /// `/api` catch-all.
  FakeResponse Function(String path, String? query)? handler;

  static Future<FakeApiServer> start([
    FakeResponse Function(String path, String? query)? handler,
  ]) async {
    final fake = await FakeApiServer._bind();
    fake.handler = handler;
    unawaited(fake._serve());
    return fake;
  }

  static Future<FakeApiServer> _bind() async =>
      FakeApiServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  Future<void> _serve() async {
    await for (final request in _server) {
      final path = request.uri.path;
      requests.add(path);
      lastQuery = request.uri.query.isEmpty ? null : request.uri.query;
      lastBody = await utf8.decodeStream(request);
      lastMethod = request.method;

      final response = handler?.call(path, request.uri.query);
      if (response == null) {
        request.response.headers.contentType = ContentType.json;
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(notFoundEnvelope);
      } else {
        response.writeTo(request.response);
      }
      await request.response.close();
    }
  }

  int get port => _server.port;

  String get baseUrl => 'http://127.0.0.1:$port';

  Future<void> stop() => _server.close(force: true);

  /// Whether a real socket could be bound.
  ///
  /// `dart:io`'s `HttpServer` does not exist on web, so these tests cannot run
  /// under `flutter test --platform chrome`. The caller detects this and skips
  /// rather than reporting a pass that never exercised anything.
  static bool get isSupported => !kIsWeb;

  /// Starts a server, or returns `null` where sockets are unavailable.
  static Future<FakeApiServer?> tryStart([
    FakeResponse Function(String path, String? query)? handler,
  ]) async {
    if (!isSupported) {
      return null;
    }
    return start(handler);
  }

  /// A port with nothing listening on it, for connection-failure tests.
  ///
  /// Returns `null` where sockets are unavailable.
  static Future<int?> tryUnusedPort() async {
    if (!isSupported) {
      return null;
    }
    final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    return port;
  }
}

/// A canned HTTP response.
class FakeResponse {
  const FakeResponse.json(
    this.body, {
    this.status = HttpStatus.ok,
    this.contentType = 'application/json; charset=utf-8',
  }) : isEmpty = false;

  /// A `204 No Content` — no body at all.
  const FakeResponse.noContent()
    : body = '',
      status = HttpStatus.noContent,
      contentType = null,
      isEmpty = true;

  /// A body that is not JSON at all, e.g. the SPA fallback serving
  /// `index.html` with HTTP 200.
  const FakeResponse.html(this.body)
    : status = HttpStatus.ok,
      contentType = 'text/html; charset=utf-8',
      isEmpty = false;

  /// JSON that claims to be JSON in the header but does not parse.
  const FakeResponse.malformedJson(this.body)
    : status = HttpStatus.ok,
      contentType = 'application/json; charset=utf-8',
      isEmpty = false;

  final String body;
  final int status;
  final String? contentType;
  final bool isEmpty;

  void writeTo(HttpResponse response) {
    if (isEmpty) {
      response.statusCode = status;
      return;
    }
    response.statusCode = status;
    response.headers.set(HttpHeaders.contentTypeHeader, contentType!);
    response.write(body);
  }
}

/// The exact 404 body the server's `/api` catch-all returns.
const String notFoundEnvelope =
    '{"success":false,"data":{},'
    '"error":{"message":"API endpoint not found"}}';

/// An [ApiClient] wired to [server], with a token store that holds no token.
///
/// The base URL is only known at runtime once the ephemeral port is bound, so
/// neither `Dio` nor its `BaseOptions` can be const.
ApiClient clientFor(FakeApiServer server) =>
    ApiClient(const TokenStore.secure(), dio: _dioFor(server.baseUrl));

/// An [ApiClient] pointed at [port], for connection-failure tests.
ApiClient clientForPort(int port) => ApiClient(
  const TokenStore.secure(),
  dio: _dioFor('http://127.0.0.1:$port'),
);

Dio _dioFor(String baseUrl) => Dio(BaseOptions(baseUrl: baseUrl));
