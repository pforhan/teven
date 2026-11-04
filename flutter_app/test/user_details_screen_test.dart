import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/routing/app_router.dart';
import 'package:teven_app/screens/users/user_details_screen.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

/// The user details screen
///
/// Covers the read-only page the user list's name links land on, and the edit
/// affordance that leads onward to the edit screen. Routing itself is pinned in
/// `router_test.dart`; what lives here is the screen's own behaviour.
void main() {
  const viewUsers = 'VIEW_USERS_ORGANIZATION';
  const manageUsersGlobal = 'MANAGE_USERS_GLOBAL';

  /// Opens `/users/42` — the id the stubbed backend answers every user lookup
  /// with.
  Future<ProviderContainer> openUserDetails(
    WidgetTester tester,
    StubAdapter adapter,
  ) async {
    final container = await pumpApp(
      tester,
      width: 1500.0,
      token: 'token',
      adapter: adapter,
    );
    await goTo(tester, container, '/users/42');
    return container;
  }

  group('rendering', () {
    testWidgets('shows the user the server returned', (tester) async {
      final adapter = contextAdapter(permissions: [viewUsers]);
      await openUserDetails(tester, adapter);

      expect(find.byType(UserDetailsScreen), findsOneWidget);
      expect(find.text('User Details'), findsOneWidget);
      expect(find.text('Username: ada'), findsOneWidget);
      expect(find.text('Display Name: Ada'), findsOneWidget);
      expect(find.text('Email: ada@example.com'), findsOneWidget);
      expect(find.text('Roles: Admin'), findsOneWidget);
      // The staff block renders only for a user who has one, and the stubbed
      // user does not.
      expect(find.text('Skills:'), findsNothing);
    });

    testWidgets('a failure shows the server message rather than spinning on', (
      tester,
    ) async {
      // A hand-rolled adapter rather than [contextAdapter]: the shared one
      // answers *every* `/api/users/{id}` lookup, and the only way to make
      // this screen's own fetch fail is to answer this one differently. The
      // context, the initial location's events calls and the rest keep their
      // canned answers, so the test fails on the screen rather than on the
      // boot sequence.
      final adapter = StubAdapter((options) {
        if (options.path == '/api/users/context') {
          return StubResponse.json(userContextJson(permissions: [viewUsers]));
        }
        if (options.method == 'GET' && options.path.startsWith('/api/users/')) {
          return const StubResponse.json(
            '{"success":false,"data":{},'
            '"error":{"message":"User service unavailable"}}',
            status: 500,
          );
        }
        if (options.method == 'GET' && options.path == '/api/events') {
          return const StubResponse.json(
            '{"success":true,"data":{"items":[],"total":0,"limit":25,"offset":0}}',
          );
        }
        if (options.method == 'GET' &&
            options.path == '/api/events/rsvps/requested') {
          return const StubResponse.json('{"success":true,"data":[]}');
        }
        // Anything else the boot sequence asks for is left to the default: a
        // 404 envelope, which is not a 401 and so does not trip the
        // single-flight redirect.
        return null;
      });

      await openUserDetails(tester, adapter);

      expect(find.text('Error: User service unavailable'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('the edit affordance', () {
    testWidgets('a manager gets an edit button that opens the edit screen', (
      tester,
    ) async {
      final adapter = contextAdapter(
        permissions: [viewUsers, manageUsersGlobal],
      );
      final container = await openUserDetails(tester, adapter);

      expect(find.text('Edit'), findsOneWidget);
      await tester.tap(find.text('Edit'));
      await settleRequests(tester);

      expect(currentPath(container), AppRoutes.userEditPath(42));
    });

    testWidgets('a viewer without manage rights gets no edit button', (
      tester,
    ) async {
      final adapter = contextAdapter(permissions: [viewUsers]);
      await openUserDetails(tester, adapter);

      expect(find.text('Edit'), findsNothing);
    });
  });
}
