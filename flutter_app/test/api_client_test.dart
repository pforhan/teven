import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/core/api/api_client.dart';
import 'package:teven_app/core/api/api_exception.dart';

import 'support/fake_api_server.dart';

/// Response-shape handling for [ApiClient] — task 1.19.
///
/// The cases here exist because the server does not respond uniformly: error
/// bodies carry `data: {}` rather than `null`, permission failures bypass the
/// envelope entirely, deletes answer `204` with no body, and an unmatched route
/// falls through to the SPA handler with `index.html` at HTTP 200. Each of
/// those broke the client in a different way before it was handled.
void main() {
  // dart:io sockets do not exist on web; skip rather than pass vacuously.
  if (!FakeApiServer.isSupported) {
    test(
      'ApiClient socket tests require a VM',
      () {},
      skip: 'dart:io unavailable',
    );
    return;
  }

  late FakeApiServer server;
  late ApiClient client;

  tearDown(() async {
    if (FakeApiServer.isSupported) {
      await server.stop();
    }
  });

  /// Starts a server that answers every path with [response].
  Future<void> respondWith(FakeResponse response) async {
    server = (await FakeApiServer.tryStart((_, _) => response))!;
    client = clientFor(server);
  }

  /// GET returning the response's `data` field.
  Future<Object?> getRaw(String path) =>
      client.get<Object?>(path, decode: (json) => json!);

  /// GET decoding `data` as an event-shaped object, for the success path.
  Future<String> getTitle(String path) => client.get<String>(
    path,
    decode: (json) => (json! as Map<String, dynamic>)['title'] as String,
  );

  group('envelope', () {
    setUp(
      () => respondWith(
        const FakeResponse.json(
          '{"success":true,"data":{"eventId":7,"title":"Gala",'
          '"date":"2026-03-04","time":"09:30:00","organizationId":1}}',
        ),
      ),
    );

    test('unwraps data on success', () async {
      final title = await getTitle('/api/thing');
      expect(title, 'Gala');
    });
  });

  group('failure envelope carries data:{} and still yields the message', () {
    setUp(
      () => respondWith(
        const FakeResponse.json(
          '{"success":false,"data":{},'
          '"error":{"message":"Event not found","details":"stack"}}',
          status: HttpStatus.badRequest,
        ),
      ),
    );

    test('message and details survive', () async {
      await expectLater(
        getTitle('/api/thing'),
        throwsA(
          isA<ApiRequestException>()
              .having((e) => e.message, 'message', 'Event not found')
              .having((e) => e.details, 'details', 'stack')
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });
  });

  group('bare-string bodies', () {
    setUp(
      () => respondWith(
        const FakeResponse.json(
          '"User does not have the required permission"',
          status: HttpStatus.forbidden,
        ),
      ),
    );

    test('403 surfaces the server text, not a generic message', () async {
      await expectLater(
        getRaw('/api/thing'),
        throwsA(
          isA<ApiRequestException>().having(
            (e) => e.message,
            'message',
            'User does not have the required permission',
          ),
        ),
      );
    });
  });

  group('401', () {
    test('inside an envelope becomes UnauthorizedException', () async {
      await respondWith(
        const FakeResponse.json(
          '{"success":false,"data":{},'
          '"error":{"message":"User ID not found in token"}}',
          status: HttpStatus.unauthorized,
        ),
      );
      await expectLater(
        getRaw('/api/thing'),
        throwsA(
          isA<UnauthorizedException>()
              .having((e) => e.message, 'message', 'User ID not found in token')
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('with no parsable body still becomes UnauthorizedException', () async {
      await respondWith(
        const FakeResponse.json('{}', status: HttpStatus.unauthorized),
      );
      await expectLater(
        getRaw('/api/thing'),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('non-JSON 200 is not success', () {
    test('index.html from the SPA fallback is rejected', () async {
      await respondWith(
        const FakeResponse.html(
          '<!DOCTYPE html><html><head><base href="/"></head></html>',
        ),
      );
      await expectLater(
        getRaw('/api/thing'),
        throwsA(
          isA<ApiRequestException>().having(
            (e) => e.message,
            'message',
            contains('did not return an API response'),
          ),
        ),
      );
    });

    test('a JSON content-type with an unparsable body is also rejected', () async {
      // Without the content-type check this would fall through the bare-string
      // path and be reported as a successful string response.
      await respondWith(const FakeResponse.malformedJson('{not json'));
      await expectLater(
        getRaw('/api/thing'),
        throwsA(isA<ApiRequestException>()),
      );
    });
  });

  group('204 empty body', () {
    test('delete completes with no payload', () async {
      await respondWith(const FakeResponse.noContent());
      await expectLater(client.delete('/api/thing'), completes);
    });

    test('a read that expected data fails clearly', () async {
      await respondWith(const FakeResponse.noContent());
      await expectLater(
        getRaw('/api/thing'),
        throwsA(isA<ApiRequestException>()),
      );
    });
  });

  group('transport failures', () {
    test('connection refused becomes NetworkException', () async {
      final port = await FakeApiServer.tryUnusedPort();
      expect(port, isNotNull, reason: 'requires a socket');
      await expectLater(
        clientForPort(port!)
            .get<Object?>('/api/thing', decode: (json) => json!),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
