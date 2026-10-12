import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/core/api/token_store.dart';
import 'package:teven_app/main.dart';
import 'package:teven_app/providers/auth_controller.dart';
import 'package:teven_app/providers/service_providers.dart';
import 'package:teven_app/routing/app_router.dart';

import 'stub_adapter.dart';

/// A user context body, as JSON text.
///
/// Hand-rolled rather than built from the model so that a change to the model
/// cannot quietly change what these tests are asserting about the *wire*
/// shape.
String userContextJson({List<String> permissions = const []}) => jsonEncode({
  'success': true,
  'data': {
    'user': {
      'userId': 1,
      'username': 'ada',
      'email': '',
      'displayName': '',
      'roles': ['Admin'],
      'organization': {
        'organizationId': 1,
        'name': 'Acme',
        'contactInformation': '',
      },
    },
    'permissions': permissions,
  },
});

/// Answers `/api/users/context` with [permissions], and everything else with a
/// 401 envelope.
StubAdapter contextAdapter({
  List<String> permissions = const [],
  String token = 'token',
}) => StubAdapter((options) {
  if (options.path == '/api/users/context') {
    return StubResponse.json(userContextJson(permissions: permissions));
  }
  if (options.method == 'POST' && options.path == '/api/users/login') {
    return StubResponse.json(
      jsonEncode({
        'success': true,
        'data': {
          'token': token,
          'user': {
            'userId': 1,
            'username': 'ada',
            'email': '',
            'displayName': '',
            'roles': ['Admin'],
            'organization': {
              'organizationId': 1,
              'name': 'Acme',
              'contactInformation': '',
            },
          },
        },
      }),
    );
  }
  return const StubResponse.json(
    '{"success":false,"data":{},"error":{"message":"Unauthorized"}}',
    status: 401,
  );
});

/// A container wired for tests: in-memory token, stubbed transport.
///
/// Overrides [tokenStoreProvider] and [dioProvider] rather than
/// [apiClientProvider], so the production wiring of the 401 hook — the thing
/// under test — is the real code.
ProviderContainer authTestContainer({
  String? token,
  required StubAdapter adapter,
}) {
  final container = ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(TokenStore.inMemory(token: token)),
      dioProvider.overrideWithValue(stubDio(adapter)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Boots the real app over a stubbed backend and settles it.
///
/// Returns the container so the test can drive the router afterwards.
///
/// Two details are load-bearing and easy to trip over again:
///
/// - **The context is resolved inside `tester.runAsync`.** The stubbed
///   transport still completes through dio's async machinery, which the fake
///   clock a widget test runs under will not advance. Awaiting it in a plain
///   `test()` hangs the run rather than failing it.
/// - **`TevenApp` is pumped, not a hand-built `MaterialApp.router`.** The
///   redirects only run once the router is attached to a widget tree, so a
///   container-only router would silently pass every assertion by never
///   redirecting at all.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required StubAdapter adapter,
  String? token,
}) async {
  final container = authTestContainer(adapter: adapter, token: token);

  await tester.runAsync(() => container.read(authControllerProvider.future));

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const TevenApp()),
  );
  await tester.pumpAndSettle();

  return container;
}

/// Navigates and settles, then reports the resulting path.
Future<String> goTo(
  WidgetTester tester,
  ProviderContainer container,
  String path,
) async {
  container.read(routerProvider).go(path);
  await tester.pumpAndSettle();
  return currentPath(container);
}

String currentPath(ProviderContainer container) =>
    container.read(routerProvider).routeInformationProvider.value.uri.path;
