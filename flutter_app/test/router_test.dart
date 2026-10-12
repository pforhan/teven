import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/core/api/api_exception.dart';
import 'package:teven_app/main.dart';
import 'package:teven_app/providers/service_providers.dart';
import 'package:teven_app/routing/app_router.dart';

import 'support/auth_harness.dart';

/// Route branching, the permission guard, and the 401 redirect —
/// tasks 2.5, 2.7, 2.8, 2.12.
///
/// A widget test, because go_router only evaluates redirects once the router is
/// attached to a widget tree. Asserted on `routeInformationProvider` rather
/// than on rendered text, so a route that resolves correctly but paints the
/// wrong screen is not mistaken for a routing failure.
void main() {
  const viewEvents = 'VIEW_EVENTS_ORGANIZATION';

  group('signed out', () {
    // `App.tsx:40-41`: only `/login` exists under this branch.
    testWidgets('every other path redirects to /login', (tester) async {
      final container = await pumpApp(tester, adapter: contextAdapter());

      for (final path in [
        AppRoutes.events,
        AppRoutes.customers,
        AppRoutes.profile,
        '/does-not-exist',
      ]) {
        expect(
          await goTo(tester, container, path),
          AppRoutes.login,
          reason: path,
        );
      }
    });

    testWidgets('/login and /register stay put', (tester) async {
      final container = await pumpApp(tester, adapter: contextAdapter());

      expect(await goTo(tester, container, AppRoutes.login), AppRoutes.login);
      // An invitee arrives here from an emailed link with no session, so this
      // one has to survive the signed-out branch — `App.tsx:66` sits outside it.
      expect(
        await goTo(tester, container, AppRoutes.register),
        AppRoutes.register,
      );
    });

    testWidgets('/login renders the login form', (tester) async {
      await pumpApp(tester, adapter: contextAdapter());

      // "Login" twice: the card heading and the submit button.
      expect(find.text('Login'), findsNWidgets(2));
      expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    });
  });

  group('signed in', () {
    testWidgets('an unknown path falls through to /events', (tester) async {
      // `App.tsx:67` sends the catch-all to `/`, whose index redirects on.
      final container = await pumpApp(
        tester,
        token: 'token',
        adapter: contextAdapter(permissions: [viewEvents]),
      );

      expect(
        await goTo(tester, container, '/does-not-exist'),
        AppRoutes.events,
      );
    });

    testWidgets('/login redirects to /events', (tester) async {
      // `/login` is not in the authenticated branch at all, so it resolves
      // through the same catch-all.
      final container = await pumpApp(
        tester,
        token: 'token',
        adapter: contextAdapter(permissions: [viewEvents]),
      );

      expect(await goTo(tester, container, AppRoutes.login), AppRoutes.events);
    });

    testWidgets('a deep link survives with its parameters', (tester) async {
      final container = await pumpApp(
        tester,
        token: 'token',
        adapter: contextAdapter(permissions: [viewEvents]),
      );

      expect(await goTo(tester, container, '/events/42'), '/events/42');
    });

    testWidgets('the root redirects to /events', (tester) async {
      // `App.tsx:41`.
      final container = await pumpApp(
        tester,
        token: 'token',
        adapter: contextAdapter(permissions: [viewEvents]),
      );

      expect(await goTo(tester, container, '/'), AppRoutes.events);
    });
  });

  group('permission guard', () {
    testWidgets('a missing permission sends the user to /events', (
      tester,
    ) async {
      // `ProtectedRoute.tsx:27`.
      final container = await pumpApp(
        tester,
        token: 'token',
        adapter: contextAdapter(permissions: [viewEvents]),
      );

      expect(
        await goTo(tester, container, AppRoutes.customers),
        AppRoutes.events,
      );
    });

    testWidgets('either scope suffices for /users/create', (tester) async {
      // `App.tsx:62` passes an array and `ProtectedRoute.tsx:22-25` treats it
      // as `.some()`. One case per scope: both halves matter, and the failure
      // mode — an org admin locked out of user creation — reads like a missing
      // permission rather than a broken guard.
      for (final permission in const [
        'MANAGE_USERS_ORGANIZATION',
        'MANAGE_USERS_GLOBAL',
      ]) {
        final container = await pumpApp(
          tester,
          token: 'token',
          adapter: contextAdapter(permissions: [permission]),
        );

        expect(
          await goTo(tester, container, AppRoutes.userCreate),
          AppRoutes.userCreate,
          reason: permission,
        );
      }
    });

    testWidgets('/users/edit needs the global scope alone', (tester) async {
      // `App.tsx:63` gates edit on `MANAGE_USERS_GLOBAL` only, unlike the
      // create route. Task 5.12 re-opens whether that asymmetry is intended;
      // for now the port reproduces it rather than quietly "fixing" it.
      final container = await pumpApp(
        tester,
        token: 'token',
        adapter: contextAdapter(permissions: ['MANAGE_USERS_ORGANIZATION']),
      );

      expect(await goTo(tester, container, '/users/edit/7'), AppRoutes.profile);
    });

    testWidgets('/profile needs no permission at all', (tester) async {
      // `App.tsx:59` — the one authenticated route with no guard.
      final container = await pumpApp(
        tester,
        token: 'token',
        adapter: contextAdapter(permissions: const []),
      );

      expect(
        await goTo(tester, container, AppRoutes.profile),
        AppRoutes.profile,
      );
    });

    testWidgets('a user who cannot see events lands somewhere reachable', (
      tester,
    ) async {
      // `/events` is the unauthorized fallback, and it is itself guarded. A
      // user without `VIEW_EVENTS_ORGANIZATION` would be redirected there and
      // denied again, which go_router resolves as a redirect loop. The guard
      // falls back to `/profile` instead; see `_requirePermission`.
      final container = await pumpApp(
        tester,
        token: 'token',
        adapter: contextAdapter(permissions: const ['MANAGE_USERS_GLOBAL']),
      );

      expect(
        await goTo(tester, container, AppRoutes.customers),
        AppRoutes.profile,
      );
    });
  });

  group('401 redirect', () {
    testWidgets('is single-flight under concurrent 401s', (tester) async {
      // Every in-flight request carrying the same dead token sees its own 401.
      // Each navigating separately would have the router fighting itself to
      // `/login`; the latch in `UnauthorizedRedirect` is what prevents it.
      final adapter = contextAdapter(permissions: [viewEvents]);
      final container = await pumpApp(tester, token: 'token', adapter: adapter);
      expect(currentPath(container), AppRoutes.events);

      await tester.runAsync(() async {
        final client = container.read(apiClientProvider);
        final attempts = [
          client.get<void>('/api/anything', decode: (_) {}),
          client.get<void>('/api/anything', decode: (_) {}),
          client.get<void>('/api/anything', decode: (_) {}),
        ];
        await Future.wait(
          attempts.map(
            (attempt) =>
                expectLater(attempt, throwsA(isA<UnauthorizedException>())),
          ),
        );
      });
      await tester.pumpAndSettle();

      expect(currentPath(container), AppRoutes.login);
      expect(
        adapter.requests.where((r) => r.path == '/api/users/context').length,
        1,
        reason: 'one context refetch, not three',
      );
      expect(await container.read(tokenStoreProvider).read(), isNull);
    });

    testWidgets('the loading gate holds the screen during the boot fetch', (
      tester,
    ) async {
      // `App.tsx:34-36`. The gate matters most for a deep link: the redirect
      // alone would let a public path such as `/register` through with no
      // context behind it, and would bounce a private one to `/login` before
      // the token had even been read.
      final container = authTestContainer(adapter: contextAdapter());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TevenApp(),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Username'), findsNothing);

      await tester.pumpAndSettle();

      expect(find.text('Loading...'), findsNothing);
      expect(currentPath(container), AppRoutes.login);
    });
  });
}
