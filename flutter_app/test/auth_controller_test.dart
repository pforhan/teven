import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/core/api/api_exception.dart';
import 'package:teven_app/models/permissions.dart';
import 'package:teven_app/providers/auth_controller.dart';
import 'package:teven_app/providers/service_providers.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

/// Auth state and permission derivation — tasks 2.1, 2.3, 2.12.
///
/// Provider-level only. The router's use of this state is covered in
/// `router_test.dart`, which needs a widget tree.
void main() {
  group('boot sequence', () {
    test('a stored token fetches the context', () async {
      final container = authTestContainer(
        token: 'token',
        adapter: contextAdapter(permissions: ['VIEW_EVENTS_ORGANIZATION']),
      );

      final context = await container.read(authControllerProvider.future);

      expect(context?.user.username, 'ada');
      expect(context?.permissions, ['VIEW_EVENTS_ORGANIZATION']);
    });

    test('no token means no request at all', () async {
      // `AuthContext.tsx:33-37` returns before touching the network. Asserting
      // the absence of a request catches a regression that is otherwise
      // invisible: a 401 treated as "logged out" looks identical at the call
      // site but costs a round trip on every cold boot.
      final adapter = contextAdapter();
      final container = authTestContainer(adapter: adapter);

      expect(await container.read(authControllerProvider.future), isNull);
      expect(adapter.requests, isEmpty);
    });

    test('a 401 on the context fetch leaves the user signed out', () async {
      final container = authTestContainer(
        token: 'stale',
        adapter: StubAdapter(
          (_) => const StubResponse.json(
            '{"success":false,"data":{},"error":{"message":"nope"}}',
            status: 401,
          ),
        ),
      );

      expect(await container.read(authControllerProvider.future), isNull);
    });

    test('a network failure also leaves the user signed out', () async {
      // `AuthContext.tsx:47` swallows every non-401 the same way. Recorded as
      // a test because it is a deliberate port, not an oversight: an outage
      // presents as "please log in", with no error anywhere.
      final container = authTestContainer(
        token: 'token',
        adapter: StubAdapter((_) => throw const NetworkException('offline')),
      );

      expect(await container.read(authControllerProvider.future), isNull);
    });
  });

  group('permissions', () {
    test('derive from the context', () async {
      final container = authTestContainer(
        token: 'token',
        adapter: contextAdapter(permissions: ['VIEW_USERS_GLOBAL']),
      );
      await container.read(authControllerProvider.future);

      expect(
        container.read(permissionGateProvider).has(Permission.viewUsersGlobal),
        isTrue,
      );
      expect(
        container
            .read(permissionGateProvider)
            .has(Permission.manageUsersGlobal),
        isFalse,
      );
    });

    test('default to none when signed out', () async {
      // `AuthContext.tsx:87` defaults to `[]`. Same default here so a screen
      // never has to distinguish "no permissions" from "nobody signed in".
      final container = authTestContainer(adapter: contextAdapter());
      await container.read(authControllerProvider.future);

      expect(container.read(permissionsProvider), isEmpty);
      expect(
        container.read(permissionGateProvider).has(Permission.viewUsersGlobal),
        isFalse,
      );
    });

    test('an array requirement is OR, not AND', () async {
      // `App.tsx:62` gates `/users/create` on either scope and
      // `ProtectedRoute.tsx:22-25` implements that as `.some()`. Reading it as
      // "all of" locks out every org-scoped admin — a failure that looks like
      // a missing permission rather than a logic error.
      const gate = PermissionGate(['MANAGE_USERS_ORGANIZATION']);
      const required = [
        Permission.manageUsersGlobal,
        Permission.manageUsersOrganization,
      ];

      expect(gate.hasAny(required), isTrue);
      expect(const PermissionGate([]).hasAny(required), isFalse);
    });

    test('an empty requirement grants access', () async {
      // `ProtectedRoute.tsx:20` renders children unconditionally when no
      // permission prop is passed, which is how `/profile` works.
      expect(const PermissionGate([]).hasAny(const []), isTrue);
    });
  });

  group('login', () {
    test('persists the token and reloads the context', () async {
      final container = authTestContainer(adapter: contextAdapter());

      await container
          .read(authControllerProvider.notifier)
          .login(username: 'ada', password: 'hunter2');

      expect(await container.read(tokenStoreProvider).read(), 'token');
      expect(container.read(userContextProvider)?.user.username, 'ada');
    });

    test('a failed login leaves the app signed out', () async {
      final container = authTestContainer(
        adapter: StubAdapter(
          (_) => const StubResponse.json(
            '{"success":false,"data":{},"error":'
            '{"message":"Invalid username or password"}}',
            status: 401,
          ),
        ),
      );

      await expectLater(
        container
            .read(authControllerProvider.notifier)
            .login(username: 'ada', password: 'wrong'),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(container.read(userContextProvider), isNull);
    });

    test('rearms the 401 latch', () async {
      // The latch must not stay closed for the life of the session, or the
      // next genuine expiry — a different cause, minutes later — is silently
      // ignored. The React flag at `AuthContext.tsx:16` never resets; this is
      // the one place the port deliberately differs.
      final container = authTestContainer(adapter: contextAdapter());
      await container.read(authControllerProvider.future);

      final latch = container.read(unauthorizedRedirectProvider.notifier);
      latch.report(const UnauthorizedException());
      expect(container.read(unauthorizedRedirectProvider), isTrue);

      await container
          .read(authControllerProvider.notifier)
          .login(username: 'ada', password: 'hunter2');

      expect(container.read(unauthorizedRedirectProvider), isFalse);
    });
  });

  group('logout', () {
    test('drops the token and the context', () async {
      final container = authTestContainer(
        token: 'token',
        adapter: contextAdapter(),
      );
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).logout();

      expect(await container.read(tokenStoreProvider).read(), isNull);
      expect(container.read(userContextProvider), isNull);
    });
  });
}
