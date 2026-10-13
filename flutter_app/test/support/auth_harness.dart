import 'dart:convert';
import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teven_app/core/api/token_store.dart';
import 'package:teven_app/main.dart';
import 'package:teven_app/providers/auth_controller.dart';
import 'package:teven_app/providers/organization_controller.dart';
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
///
/// `/api/organizations` is answered too, because the chrome asks for it as soon
/// as a super-admin is signed in — the super-admin branch of the organization
/// selector (`MainLayout.tsx:30`) builds the switcher, which fetches the list.
/// Without this the stub would return 401 for it, the client would raise a
/// [teven_app.core.api.api_exception.UnauthorizedException], and the
/// single-flight 401 redirect would sign the test out mid-assertion.
StubAdapter contextAdapter({
  List<String> permissions = const [],
  String token = 'token',
  List<String> organizationNames = const ['Acme', 'Globex'],
}) => StubAdapter((options) {
  if (options.path == '/api/users/context') {
    return StubResponse.json(userContextJson(permissions: permissions));
  }
  if (options.path == '/api/organizations') {
    return StubResponse.json(
      jsonEncode({
        'success': true,
        'data': {
          'items': [
            for (var i = 0; i < organizationNames.length; i++)
              {
                'organizationId': i + 1,
                'name': organizationNames[i],
                'contactInformation': '',
              },
          ],
          'total': organizationNames.length,
          'limit': 1000,
          'offset': 0,
        },
      }),
    );
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
///
/// Seeds `SharedPreferences` too. The organization controller reads it on
/// construction (`OrganizationController.build`), and without a mock the plugin
/// throws `MissingPluginException` — which is a fine failure for a plugin test
/// and a confusing one for anything that happens to render the chrome.
ProviderContainer authTestContainer({
  String? token,
  required StubAdapter adapter,
  Map<String, Object> prefs = const {},
}) {
  SharedPreferences.setMockInitialValues(prefs);
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
/// Three details are load-bearing and easy to trip over again:
///
/// - **The context is resolved inside `tester.runAsync`.** The stubbed
///   transport still completes through dio's async machinery, which the fake
///   clock a widget test runs under will not advance. Awaiting it in a plain
///   `test()` hangs the run rather than failing it.
/// - **`TevenApp` is pumped, not a hand-built `MaterialApp.router`.** The
///   redirects only run once the router is attached to a widget tree, so a
///   container-only router would silently pass every assertion by never
///   redirecting at all.
/// - **[width] pins the surface.** It exists for the responsive tests; the
///   default 800x600 is already the tablet layout, which is a fact worth
///   remembering when a chrome assertion appears to depend on it.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required StubAdapter adapter,
  String? token,
  double? width,
  Map<String, Object> prefs = const {},
}) async {
  if (width != null) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  final container = authTestContainer(
    adapter: adapter,
    token: token,
    prefs: prefs,
  );

  await tester.runAsync(() => container.read(authControllerProvider.future));

  // Same reason, for the super-admin's selected organization: it is restored
  // from `SharedPreferences`, which on web is a real async hop that the fake
  // clock does not advance. Reading it here means the value is settled before
  // anything paints, rather than the chrome rendering "All Organizations" and
  // then flipping. Only preferences are touched — no request is made.
  await tester.runAsync(
    () => container.read(organizationControllerProvider.future),
  );

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
