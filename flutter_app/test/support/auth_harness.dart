import 'dart:convert';
import 'dart:ui' show Size;

import 'package:dio/dio.dart' show RequestOptions;
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
///
/// [forOtherRoutes] answers anything else — the list screens' own endpoints.
/// Returning null from it falls through to the 401, so a test can leave the
/// paths it does not care about unauthorized and catch an accidental call to
/// one of them.
///
/// [organizationsResponder] overrides the canned `/api/organizations` page.
/// It exists because **the organization list screen cannot be tested through
/// [forOtherRoutes]**: the branch above matches on path alone, so it claims
/// that path before `forOtherRoutes` is ever consulted. The first version of
/// `organization_list_screen_test.dart` learned that the hard way — the screen
/// rendered the harness's two canned organizations, and a stubbed *failure* on
/// its endpoint had no effect at all. It receives the query string so a caller
/// can tell the chrome's `limit=1000` request from the screen's `limit=25`.
///
/// [rolesResponder] does the same for `/api/roles`, for the same reason.
/// `CreateInvitationForm` needs a role to exist before it can mint anything, and
/// the canned empty list would leave every test unable to get past the form's own
/// "Please select one role." guard — a test that passes for the wrong reason
/// rather than one that fails loudly.
StubAdapter contextAdapter({
  List<String> permissions = const [],
  String token = 'token',
  List<String> organizationNames = const ['Acme', 'Globex'],
  StubResponse Function(String? query)? organizationsResponder,
  StubResponse Function()? rolesResponder,
  StubResponse? Function(RequestOptions options)? forOtherRoutes,
}) => StubAdapter((options) {
  if (options.path == '/api/users/context') {
    return StubResponse.json(userContextJson(permissions: permissions));
  }
  if (options.path == '/api/organizations') {
    final responder = organizationsResponder;
    if (responder != null) {
      return responder(options.uri.query);
    }
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
  if (options.method == 'GET' && options.path.startsWith('/api/users/')) {
    return StubResponse.json(
      jsonEncode({
        'success': true,
        'data': {
          'userId': 1,
          'username': 'ada',
          'email': 'ada@example.com',
          'displayName': 'Ada',
          'roles': ['Admin'],
          'organization': {
            'organizationId': 1,
            'name': 'Acme',
            'contactInformation': '',
          },
        },
      }),
    );
  }
  if (options.method == 'GET' && options.path == '/api/roles') {
    // Answered for the same reason as `/api/users/{id}` above: the create-user
    // screen lists roles on arrival, and a test that only means to assert that
    // the *guard* admitted the route should not have to know that. Empty
    // unless [rolesResponder] says otherwise, because the role list's contents
    // are `services_test.dart`'s subject and nobody else asserts on them
    // through this harness.
    return rolesResponder?.call() ??
        const StubResponse.json('{"success":true,"data":[]}');
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
  return forOtherRoutes?.call(options) ??
      const StubResponse.json(
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
  double? height,
  Map<String, Object> prefs = const {},
}) async {
  if (width != null || height != null) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width ?? 800, height ?? 900);
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

/// Gives in-flight stubbed requests a chance to finish, then settles.
///
/// Same constraint as [pumpApp]: the stub is answered through dio's async
/// machinery, which a widget test's fake clock will not advance, so
/// `pumpAndSettle` alone can hang on it or time out against a spinner.
///
/// The loop does both halves, and **both are needed**. A request started from
/// inside a frame — a screen's own provider, rather than the boot fetch that
/// [pumpApp] awaits — registers its zero-duration timers on the *fake* clock,
/// so `pump()` with no duration never fires them and the request never leaves
/// `AsyncLoading`. Advancing the clock inside `runAsync` lets the real async
/// machinery drain. Skipping either half leaves a `CircularProgressIndicator`
/// spinning and `pumpAndSettle` timing out with no explanation — which is
/// exactly what it did on Chrome before this was written down.
///
/// A few short waits cover a stub that resolves immediately, without the test
/// having to know which provider a given screen happens to use.
Future<void> settleRequests(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
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

/// Navigates to [path] where the destination does not fetch on arrival.
///
/// `goTo` settles the navigation animation, which is the right thing for a
/// route that renders immediately — a placeholder, a static form. A list screen
/// spins a progress indicator until its first request lands, and
/// `pumpAndSettle` will never finish against one that is still in flight. Use
/// [goToAndLoad] for those.
Future<String> goToSettled(
  WidgetTester tester,
  ProviderContainer container,
  String path,
) async {
  final landed = await goTo(tester, container, path);
  await settleRequests(tester);
  return landed;
}

/// Navigates to [path] and lets the screen's own requests finish, then reports
/// the resulting path.
///
/// The counterpart to [goTo] for a route that fetches on arrival: one frame to
/// build the screen and start its request, then [settleRequests] to let the
/// answer land. See [settleRequests] for why both halves are required — this
/// pair is what makes a list screen testable at all.
Future<String> goToAndLoad(
  WidgetTester tester,
  ProviderContainer container,
  String path,
) async {
  container.read(routerProvider).go(path);
  await tester.pump();
  await settleRequests(tester);
  return currentPath(container);
}

String currentPath(ProviderContainer container) =>
    container.read(routerProvider).routeInformationProvider.value.uri.path;
