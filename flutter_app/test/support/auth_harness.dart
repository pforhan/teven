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
///
/// [eventsResponder] is the same story again, for `/api/events`, and it is the
/// third instance rather than the first. Both `/events` and `/events/list` are
/// the app's **initial location** — the router opens there, and the `*`
/// catch-all redirects there — so every test that boots the app requests the
/// event endpoints whether or not it means to. Left to fall through to the 401,
/// that raised `UnauthorizedException`, tripped the single-flight 401 redirect,
/// and signed the user out mid-assertion: twenty-odd tests whose first symptom
/// was landing on `/login` and no rail, which reads as a broken shell rather
/// than an unanswered path.
StubAdapter contextAdapter({
  List<String> permissions = const [],
  String token = 'token',
  List<String> organizationNames = const ['Acme', 'Globex'],
  StubResponse Function(String? query)? organizationsResponder,
  StubResponse Function()? rolesResponder,
  StubResponse Function(String? query)? eventsResponder,
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
  if (options.method == 'GET' && options.path == '/api/events') {
    // **`forOtherRoutes` first, unlike `/api/organizations` above, and the
    // difference is deliberate.** This path is both the app's initial location
    // *and* the event screens' own endpoint, so a test may want either the
    // harness's blank page (a chrome or router test that merely needs no 401) or
    // its own rows (an event screen test). Answering the canned page first made
    // the second impossible: every event test rendered an empty list, and the
    // stub looked like it was working. That is the trap
    // `organization_list_screen_test.dart` recorded for the organization
    // endpoint, met here by the same mechanism and the same silence.
    final routed = forOtherRoutes?.call(options);
    if (routed != null) return routed;
    return eventsResponder?.call(options.uri.query) ??
        const StubResponse.json(
          '{"success":true,"data":{"items":[],"total":0,"limit":25,"offset":0}}',
        );
  }
  if (options.method == 'GET' &&
      options.path == '/api/events/rsvps/requested') {
    // **Answered, and the reason is the calendar.**
    //
    // The calendar carries the pending-RSVP card (task 7.6), and the router
    // opens at `/events` — so *every* test that boots the app requests this
    // path, whether or not it means to. Left to fall through to the 401, that
    // raised `UnauthorizedException`, tripped the single-flight 401 redirect
    // and signed the user out mid-assertion: fifty-odd tests whose first
    // symptom was landing on `/login` and no rail, which reads as a broken
    // shell rather than an unanswered path.
    //
    // `forOtherRoutes` first, like `/api/events` above and for the same
    // reason — a test that wants rows of its own has to be able to supply
    // them.
    final routed = forOtherRoutes?.call(options);
    if (routed != null) return routed;
    return const StubResponse.json('{"success":true,"data":[]}');
  }
  if (options.method == 'GET' &&
      RegExp(r'^/api/events/\d+$').hasMatch(options.path)) {
    // **The event details screen**, which is a real screen now (task 7.6)
    // and fetches on arrival. Unanswered it 401s, and the single-flight
    // redirect signs the user out — so a test that only means to assert
    // *where* a navigation landed would find itself on `/login`.
    //
    // The id is echoed back so the screen has a record to render rather than
    // one whose id disagrees with the URL it was reached at.
    final routed = forOtherRoutes?.call(options);
    if (routed != null) return routed;
    final id = int.parse(
      RegExp(r'^/api/events/(\d+)$').firstMatch(options.path)!.group(1)!,
    );
    return StubResponse.json(
      jsonEncode({
        'success': true,
        'data': {
          'eventId': id,
          'title': 'Event $id',
          'date': '2026-01-01',
          'time': '09:00:00',
          'durationMinutes': 60,
          'location': null,
          'latitude': null,
          'longitude': null,
          'formattedAddress': null,
          'description': null,
          'inventoryItems': <Map<String, dynamic>>[],
          'customer': null,
          'rsvps': <Map<String, dynamic>>[],
          'organization': {
            'organizationId': 1,
            'name': 'Acme',
            'contactInformation': '',
          },
          'openInvitation': false,
          'numberOfStaffNeeded': 0,
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
  // `settleRequests`, not a bare `pumpAndSettle`, and the difference is that
  // **the app's initial location is now a screen that fetches.**
  //
  // The router opens at `/events` (`app_router.dart:142`), which since task 7.1
  // is the calendar rather than a placeholder. It therefore starts a request
  // during `pumpWidget` and shows a `CircularProgressIndicator` until it lands —
  // and `pumpAndSettle` cannot settle an indeterminate animation. Every test
  // that booted the app failed with no message at all, which is the silent
  // signature this harness has produced before and the reason it is written
  // down here.
  //
  // Draining first also makes the state on arrival *settled* rather than
  // mid-flight, which is what a test wants to reason about. See
  // [settleRequests] for why both halves of its loop are needed.
  await settleRequests(tester);

  return container;
}

/// Gives in-flight stubbed requests a chance to finish, then settles.
///
/// **The one settle routine in the suite. Use this, not `pumpAndSettle`, after
/// anything that starts a request or navigates to a screen that fetches.** The
/// rule is one line long and easy to get wrong in a way that only shows on one
/// platform:
///
/// > `pumpAndSettle` cannot settle a `CircularProgressIndicator`, so calling it
/// > while a screen is still loading **times out**, and on `--platform chrome`
/// > the runner reports that timeout as `Test failed. See exception logs above.`
/// > **with nothing above it**.
///
/// That second half is why this is written down in full. A `FlutterError` raised
/// inside the web test run is not surfaced by the runner, so a genuine timeout —
/// and a genuine failed assertion — look identical in the output: a test that
/// failed, with no reason. Recovering the message needs an explicit
/// `FlutterError.onError` hook in the test body, which nobody writes when the
/// output looks like a failure rather than a missing diagnostic. **When a Chrome
/// test fails with no message, suspect this before suspecting the assertion.**
///
/// The loop does both halves, and **both are needed**. A request started from
/// inside a frame — a screen's own provider, rather than the boot fetch that
/// [pumpApp] awaits — registers its zero-duration timers on the *fake* clock,
/// so `pump()` with no duration never fires them and the request never leaves
/// `AsyncLoading`. Advancing the clock inside `runAsync` lets the real async
/// machinery drain.
///
/// **The delay has to be a real one, and that is a platform difference rather
/// than a tuning choice.** `accept_invitation_screen_test.dart` had its own
/// private settle that yielded *once* with `Future.delayed(Duration.zero)`, which
/// is enough on the VM — dio's pipeline there is microtask-based, so one
/// real-timer hop drains it. In the browser dio's web transport needs a genuine
/// event-loop turn for the response to arrive, so the request was still in
/// flight, the loading box was still up, and the closing `pumpAndSettle` timed
/// out. Ten of that file's tests failed on Chrome and passed on the VM, silently.
///
/// That private copy is gone and its six call sites now use this. **Two copies
/// of a settle routine is the defect, not a style preference**: the wrong one
/// still looks correct, because it is right on the platform it was written on.
///
/// A few short waits cover a stub that resolves immediately, without the test
/// having to know which provider a given screen happens to use.
///
/// This lives in `auth_harness.dart` rather than a file of its own, and is called
/// from the customer, inventory, user and event screen tests — so the name is
/// now a historical accident. Moving it is churn across every one of them for no
/// behaviour, so it stays.
Future<void> settleRequests(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
}

/// Navigates to [path], lets the destination settle, then reports the path.
///
/// **One navigation helper, and it drains before it settles.** There were three
/// — `goTo` (settle only), `goToAndLoad` (pump then drain then settle) and
/// `goToSettled` (settle then drain then settle) — which differed only in whether
/// the destination fetched on arrival. **That distinction is not a property of a
/// route, it is a property of whether the caller happened to know**, and getting
/// it wrong was silent: `goTo` at a fetching destination calls `pumpAndSettle`
/// against a `CircularProgressIndicator`, which never settles, so the test times
/// out and `--platform chrome` reports the timeout with no message at all.
///
/// Fourteen call sites used `goToAndLoad`, one used `goToSettled`, and twelve used
/// the unsafe `goTo`. All of them now use this, and the two others are gone. The
/// cost is a few milliseconds of real waiting on a route that renders instantly;
/// the benefit is that a new screen cannot be added to a test in a way that
/// quietly breaks it on one platform.
Future<String> goTo(
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

/// The full location — path **and** query — as the browser would show it.
///
/// [currentPath] drops the query, which is right for asserting where the user
/// landed and wrong for asserting *what was carried there*. The calendar's day
/// cells navigate to `/events/create?date=…`, and a test that checked
/// [currentPath] would pass against a bare `/events/create` while asserting
/// nothing about the date it exists to check.
String currentLocation(ProviderContainer container) => container
    .read(routerProvider)
    .routeInformationProvider
    .value
    .uri
    .toString();
