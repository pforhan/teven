import 'dart:convert';

import 'package:dio/dio.dart' show RequestOptions;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/models/invitation.dart';
import 'package:teven_app/models/user.dart';
import 'package:teven_app/routing/app_router.dart';
import 'package:teven_app/screens/users/user_list_screen.dart';
import 'package:teven_app/widgets/create_invitation_form.dart';
import 'package:teven_app/widgets/responsive_list_view.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

/// The user list — task 4.7, the remaining two delete flows of 4.8, and the
/// sort verification of 4.11.
///
/// The screen is the only one in the app that renders two tables in one route,
/// so the tests that matter here are the ones a copy of the customer screen
/// would fail: that the invitations table appears and disappears on its own
/// terms, that the two deletes reach different endpoints and refetch different
/// things, and that the organization column is conditional on a permission.
void main() {
  /// Wide enough for the extended rail (256) *and* a table (1100) beside it.
  const desktopWidth = 1500.0;
  const viewUsers = 'VIEW_USERS_ORGANIZATION';
  const viewUsersGlobal = 'VIEW_USERS_GLOBAL';
  const manageUsers = 'MANAGE_USERS_ORGANIZATION';

  /// The permissions the *form* needs, which are not the ones its button needs.
  ///
  /// **Two different sets gate one control, and the React original has the same
  /// split.** `UserList.tsx:206` puts the "Create Invitation" button under
  /// `MANAGE_USERS_GLOBAL || MANAGE_USERS_ORGANIZATION`; `CreateInvitationForm`
  /// re-checks `MANAGE_INVITATIONS_*` on itself and renders a refusal
  /// otherwise. Reproduced rather than reconciled — it is the server that
  /// enforces the second set (`InvitationRoutes.kt:77`), so the form's check is
  /// the load-bearing one and the button's is merely a wider door onto a
  /// message. Pinned by "the button and the form gate on different permissions"
  /// below.
  const manageInvitations = 'MANAGE_INVITATIONS_ORGANIZATION';
  const inviteManager = [viewUsers, manageUsers, manageInvitations];

  StubResponse usersPage(List<String> usernames) => StubResponse.json(
    jsonEncode({
      'success': true,
      'data': {
        'items': [
          for (var i = 0; i < usernames.length; i++)
            {
              'userId': i + 1,
              'username': usernames[i],
              'email': '${usernames[i]}@example.com',
              'displayName': 'Display ${i + 1}',
              'roles': ['Admin'],
              // Deliberately not "Acme", which the chrome already puts on
              // screen as the signed-in user's own organization, so a
              // `find.text('Acme')` would match twice.
              'organization': {
                'organizationId': i + 2,
                'name': 'Org ${i + 1}',
                'contactInformation': '',
              },
            },
        ],
        'total': usernames.length,
        'limit': 25,
        'offset': 0,
      },
    }),
  );

  StubResponse invitationsList(List<Map<String, Object>> invitations) =>
      StubResponse.json(jsonEncode({'success': true, 'data': invitations}));

  StubResponse invitation({
    int invitationId = 7,
    String token = 'abc123',
    String roleName = 'Volunteer',
    String? note,
    String expiresAt = '2026-12-31T00:00:00',
  }) => invitationsList([
    {
      'invitationId': invitationId,
      'organizationId': 1,
      'roleId': 2,
      'roleName': roleName,
      'token': token,
      'expiresAt': expiresAt,
      'createdAt': '2026-10-01T00:00:00',
      // Absent rather than empty when there is no note, because
      // `UserList.tsx:168` distinguishes the two: `note || 'N/A'`.
      'note': ?note,
    },
  ]);

  /// A backend for the users table and, optionally, the invitations one.
  ///
  /// **`/api/invitations` is always answered**, defaulting to an empty list.
  /// A manager's screen fetches it on arrival (`UserList.tsx:53-55`), and an
  /// unanswered path falls through to the harness's 401 — which signs the test
  /// out through the real 401 redirect and lands everything on `/login`. That
  /// is not a harness quirk to work around; it is the app behaving correctly
  /// about a 401 it was not expecting, and it is why every test here failed
  /// until the endpoint was stubbed.
  ///
  /// Anything still unrecognised falls through to the same 401, so a genuinely
  /// accidental call fails the test rather than passing quietly.
  /// What `POST /api/invitations` answers.
  ///
  /// A whole `InvitationResponse`, because `InvitationService.createInvitation`
  /// decodes one and a stub answering a bare string would fail inside
  /// deserialization rather than on an assertion.
  StubResponse createdInvitation({
    int invitationId = 11,
    String token = 'minted-token',
  }) => StubResponse.json(
    jsonEncode({
      'success': true,
      'data': {
        'invitationId': invitationId,
        'organizationId': 1,
        'roleId': 1,
        'roleName': 'Staff',
        'token': token,
        'expiresAt': '2026-12-31T00:00:00',
        'createdAt': '2026-10-01T00:00:00',
      },
    }),
  );

  StubAdapter userAdapter({
    List<String> usernames = const ['grace', 'alan'],
    List<String> permissions = const [viewUsers, manageUsers],
    StubResponse? invitations,
    StubResponse? usersFailure,
    StubResponse? invitationsFailure,
    List<String> roles = const [],
    StubResponse? createInvitationResponse,
  }) => contextAdapter(
    permissions: permissions,
    rolesResponder: () => StubResponse.json(
      jsonEncode({
        'success': true,
        'data': [
          for (var i = 0; i < roles.length; i++)
            {'roleId': i + 1, 'roleName': roles[i], 'permissions': <String>[]},
        ],
      }),
    ),
    forOtherRoutes: (options) {
      if (options.path == '/api/users' && options.method == 'GET') {
        return usersFailure ?? usersPage(usernames);
      }
      if (options.path == '/api/invitations' && options.method == 'GET') {
        return invitationsFailure ?? invitations ?? invitationsList(const []);
      }
      if (options.path == '/api/invitations' && options.method == 'POST') {
        return createInvitationResponse ?? createdInvitation();
      }
      if (options.path == '/api/invitations/7' && options.method == 'DELETE') {
        return const StubResponse.json(
          '{"success":true,"data":"Created invitation"}',
        );
      }
      if (options.method == 'DELETE' &&
          options.path.startsWith('/api/users/')) {
        // **`UserRoutes.kt` defines no `delete` route.** The request falls
        // through to the server's `/api` catch-all, which answers a JSON 404
        // envelope — so the failure the screen shows is a 404, not the 401 the
        // harness would otherwise fall back to.
        //
        // Answered explicitly rather than left to that fallback, because the
        // fallback is a **401**, and a 401 is not a neutral "not stubbed" here:
        // it trips the real unauthorized redirect, signs the test out and
        // lands it on `/login`. The first version left the path unstubbed and
        // the test failed with no error banner anywhere on screen, which reads
        // as a broken screen rather than as a stub that answered wrongly.
        return const StubResponse.json(
          '{"success":false,"data":{},'
          '"error":{"message":"API endpoint not found"}}',
          status: 404,
        );
      }
      return null;
    },
  );

  Future<ProviderContainer> openUsers(
    WidgetTester tester,
    StubAdapter adapter, {
    double width = desktopWidth,
    Map<String, Object> prefs = const {},
  }) async {
    final container = await pumpApp(
      tester,
      width: width,
      token: 'token',
      prefs: prefs,
      adapter: adapter,
    );
    await goToAndLoad(tester, container, AppRoutes.users);
    return container;
  }

  /// `GET /api/users` requests the screen made.
  List<RequestOptions> userRequests(StubAdapter adapter) => adapter.requests
      .where((o) => o.path == '/api/users' && o.method == 'GET')
      .toList();

  /// `GET /api/invitations` requests.
  List<RequestOptions> invitationRequests(StubAdapter adapter) => adapter
      .requests
      .where((o) => o.path == '/api/invitations' && o.method == 'GET')
      .toList();

  Future<void> hoverRow(WidgetTester tester, String label) async {
    final row = find.text(label);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(row));
    await gesture.moveTo(tester.getCenter(row));
    await tester.pumpAndSettle();
  }

  /// The delete button of the **users** table.
  ///
  /// Both tables have one, so `find.byIcon(Icons.delete)` alone cannot say
  /// which was tapped. Scoped by the list widget's **type argument**, which is
  /// what actually distinguishes them — an earlier version scoped by
  /// `find.ancestor(of: find.text('grace'), matching: find.byType(TableRow))`
  /// and matched nothing, because the rows a `Table` builds are its own
  /// entries rather than `TableRow` widgets in the tree.
  Finder userRowDelete() => find.descendant(
    of: find.byType(ResponsiveListView<UserResponse>),
    matching: find.byIcon(Icons.delete),
  );

  /// The delete button of the **invitations** table, for the same reason.
  Finder invitationRowDelete() => find.descendant(
    of: find.byType(ResponsiveListView<InvitationResponse>),
    matching: find.byIcon(Icons.delete),
  );

  group('rendering', () {
    testWidgets('shows the users the server returned', (tester) async {
      await openUsers(tester, userAdapter());

      expect(find.byType(UserListScreen), findsOneWidget);
      expect(find.byType(ResponsiveListView<UserResponse>), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('grace'), findsOneWidget);
      expect(find.text('alan'), findsOneWidget);
      expect(find.text('grace@example.com'), findsOneWidget);
      expect(find.text('Display 1'), findsOneWidget);
      // `UserList.tsx:139` — `user.roles.join(', ')`. Two matches, not one:
      // every fixture user has the role "Admin" and so does the signed-in
      // user the harness describes, which the chrome names.
      expect(find.text('Admin'), findsWidgets);
    });

    testWidgets('is no longer a placeholder', (tester) async {
      await openUsers(tester, userAdapter());

      expect(
        find.text('Not ported yet — see FLUTTER-CONVERT.md.'),
        findsNothing,
      );
    });

    testWidgets('queries with the original limit, sort and offset', (
      tester,
    ) async {
      final adapter = userAdapter();
      await openUsers(tester, adapter);

      // `UserList.tsx:33-40` — `getAllUsers(25, 0, search, 'username', 'asc', org)`.
      final request = userRequests(adapter).single;
      expect(request.queryParameters['limit'], 25);
      expect(request.queryParameters['offset'], 0);
      expect(request.queryParameters['sortBy'], 'username');
      expect(request.queryParameters['sortOrder'], 'asc');
      expect(request.queryParameters.containsKey('search'), isFalse);
    });

    testWidgets('scopes to the selected organization when there is one', (
      tester,
    ) async {
      final adapter = userAdapter();
      await openUsers(
        tester,
        adapter,
        prefs: {
          'selectedOrganization': jsonEncode({
            'organizationId': 7,
            'name': 'Globex',
            'contactInformation': '',
          }),
        },
      );

      // `UserList.tsx:39`, the same line the customer and inventory screens
      // have. Unlike the organization screen, this one *is* scoped.
      expect(userRequests(adapter).last.queryParameters['organizationId'], 7);
    });

    testWidgets(
      'a failure shows the server message',
      (tester) async {
        await openUsers(
          tester,
          userAdapter(
            usersFailure: const StubResponse.json(
              '{"success":false,"data":{},'
              '"error":{"message":"User service unavailable"}}',
              status: 500,
            ),
          ),
        );

        expect(find.text('Error: User service unavailable'), findsOneWidget);
      },
      // Skipped on web for the reason recorded on the customer and organization
      // screens: rendering `ErrorDisplay` after a rejected request ends in a
      // silent pending-timer teardown on Chrome — the unowned gap the Phase 3
      // log flagged, not a defect in this screen.
      skip: kIsWeb,
    );
  });

  group('search', () {
    testWidgets('is debounced rather than firing per keystroke', (
      tester,
    ) async {
      final adapter = userAdapter();
      await openUsers(tester, adapter);

      await tester.enterText(find.byType(TextField), 'gra');
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        userRequests(adapter),
        hasLength(1),
        reason: 'only the initial load',
      );

      await tester.pump(const Duration(milliseconds: 250));
      await settleRequests(tester);

      expect(userRequests(adapter), hasLength(2));
      expect(userRequests(adapter).last.queryParameters['search'], 'gra');
    });
  });

  group('permissions', () {
    testWidgets('the route is closed without VIEW_USERS_ORGANIZATION', (
      tester,
    ) async {
      final container = await pumpApp(
        tester,
        width: desktopWidth,
        token: 'token',
        adapter: userAdapter(permissions: const ['VIEW_EVENTS_ORGANIZATION']),
      );

      final landed = await goToAndLoad(tester, container, AppRoutes.users);

      expect(landed, AppRoutes.events);
      expect(find.byType(UserListScreen), findsNothing);
    });

    testWidgets('a viewer gets no create button and no row actions', (
      tester,
    ) async {
      await openUsers(tester, userAdapter(permissions: const [viewUsers]));

      expect(find.text('Create User'), findsNothing);

      await hoverRow(tester, 'grace');
      expect(userRowDelete(), findsNothing);
      // The data is still there — the gate is on the actions, not the screen.
      expect(find.text('grace'), findsOneWidget);
    });

    testWidgets('MANAGE_USERS_GLOBAL alone is enough to manage', (
      tester,
    ) async {
      // `UserList.tsx:25` ORs the two scopes. The organization screen's
      // equivalent is single-scope, so a copy of it would have gated this on
      // `MANAGE_USERS_ORGANIZATION` and locked out every super-admin.
      await openUsers(
        tester,
        userAdapter(permissions: const [viewUsers, 'MANAGE_USERS_GLOBAL']),
      );

      expect(find.text('Create User'), findsOneWidget);
      await hoverRow(tester, 'grace');
      expect(userRowDelete(), findsWidgets);
    });

    testWidgets('the organization column needs VIEW_USERS_GLOBAL', (
      tester,
    ) async {
      // `UserList.tsx:142-152` pushes the column only for a global viewer. An
      // organization-scoped admin's users are all in one organization by
      // construction, so the column would be the same value on every row —
      // which is why it is the *global* permission that adds it, not the
      // screen being global.
      await openUsers(
        tester,
        userAdapter(
          permissions: const [viewUsers, manageUsers, viewUsersGlobal],
        ),
      );

      expect(find.text('Organization'), findsOneWidget);
      expect(find.text('Org 1'), findsOneWidget);
      expect(find.text('Org 2'), findsOneWidget);
    });

    testWidgets('an organization-scoped viewer gets no organization column', (
      tester,
    ) async {
      await openUsers(
        tester,
        userAdapter(permissions: const [viewUsers, manageUsers]),
      );

      expect(find.text('Organization'), findsNothing);
      // The users themselves are unaffected — the gate is on the column.
      expect(find.text('grace'), findsOneWidget);
    });
  });

  group('sorting — task 4.11', () {
    testWidgets('a second tap on the username column reverses it', (
      tester,
    ) async {
      final adapter = userAdapter();
      await openUsers(tester, adapter);

      await tester.tap(find.text('Username'));
      await settleRequests(tester);

      expect(userRequests(adapter).map((r) => r.queryParameters['sortOrder']), [
        'asc',
        'desc',
      ]);
    });

    testWidgets('switching columns starts ascending', (tester) async {
      final adapter = userAdapter();
      await openUsers(tester, adapter);

      await tester.tap(find.text('Username'));
      await settleRequests(tester);
      await tester.tap(find.text('Email'));
      await settleRequests(tester);

      // `UserList.tsx:110-117` — a different column resets the direction.
      expect(
        userRequests(adapter).map(
          (r) => (r.queryParameters['sortBy'], r.queryParameters['sortOrder']),
        ),
        [('username', 'asc'), ('username', 'desc'), ('email', 'asc')],
      );
    });

    testWidgets('only the three columns UserDao honours are sortable', (
      tester,
    ) async {
      // `UserDao.getUsers:99-104` switches on exactly `username`, `email` and
      // `displayName`, falling through to `id`. Roles and organization have no
      // case, so offering them as sort controls would produce a header that
      // looks live and re-orders by id. This is the mismatch 4.11 asks about,
      // and on this screen client and server agree — unlike the customer
      // screen's, which offers three the server ignores.
      final adapter = userAdapter();
      await openUsers(tester, adapter);

      await tester.tap(find.text('Roles'));
      await settleRequests(tester);

      expect(userRequests(adapter).map((r) => r.queryParameters['sortBy']), [
        'username',
      ]);
    });
  });

  group('invitations', () {
    testWidgets('the section is absent when there are none', (tester) async {
      await openUsers(tester, userAdapter());

      expect(find.text('Unused Invitations'), findsNothing);
      // Only one table, then — the users'.
      expect(find.byType(Table), findsOneWidget);
    });

    testWidgets('the section renders above the users when there are some', (
      tester,
    ) async {
      await openUsers(
        tester,
        userAdapter(invitations: invitation(note: 'For the new season')),
      );

      expect(find.text('Unused Invitations'), findsOneWidget);
      // Two tables in one route — the only screen in the app that does this.
      expect(find.byType(Table), findsNWidgets(2));
      expect(find.text('Volunteer'), findsOneWidget);
      // `UserList.tsx:168` — a note is shown when present, 'N/A' when not.
      expect(find.text('For the new season'), findsOneWidget);
      expect(find.text('Copy Link'), findsOneWidget);
      // `expiresAt` rendered as a date, not as the raw timestamp.
      expect(find.text('2026-12-31'), findsOneWidget);
    });

    testWidgets('a missing note reads N/A', (tester) async {
      await openUsers(tester, userAdapter(invitations: invitation()));

      expect(find.text('N/A'), findsOneWidget);
    });

    testWidgets('a manager fetches them', (tester) async {
      final adapter = userAdapter(invitations: invitation());
      await openUsers(tester, adapter);

      // `UserList.tsx:73-75` — the fetch rides the same effect that loads the
      // users, and is skipped entirely for a caller who cannot manage them.
      expect(invitationRequests(adapter), hasLength(1));
      expect(find.text('Unused Invitations'), findsOneWidget);
    });

    testWidgets('a viewer is never asked for them', (tester) async {
      final adapter = userAdapter(
        permissions: const [viewUsers],
        invitations: invitation(),
      );
      await openUsers(tester, adapter);

      // `UserList.tsx:54` — `if (!canManageUsers) return;`. Fetching anyway
      // would be a guaranteed 403 and a guaranteed red herring in the log.
      // Split into its own case rather than sharing one with the manager
      // above: booting the app twice in a single test leaves the first
      // container's autoDispose teardown pending, which fails the test with no
      // message about either assertion.
      expect(invitationRequests(adapter), isEmpty);
      expect(find.text('Unused Invitations'), findsNothing);
    });

    testWidgets(
      'a failure to load them does not take the users table with it',
      (tester) async {
        await openUsers(
          tester,
          userAdapter(
            invitationsFailure: const StubResponse.json(
              '{"success":false,"data":{},'
              '"error":{"message":"Invitation service unavailable"}}',
              status: 500,
            ),
          ),
        );

        // The React original handed both tables one shared `error`, so a
        // failure to load invitations rendered that message twice — once per
        // table. Here it renders once and the users are still there.
        expect(
          find.text('Error: Invitation service unavailable'),
          findsOneWidget,
        );
        expect(find.text('grace'), findsOneWidget);
      },
      skip: kIsWeb,
    );

    testWidgets('the invite link is built from Uri.base', (tester) async {
      await openUsers(
        tester,
        userAdapter(invitations: invitation(token: 'tok-42')),
      );

      // Task 5.10. `UserList.tsx:157,179` writes `window.location.origin`
      // twice, once for the copy and once for the displayed text; one
      // `invitationUrl` means the two cannot disagree.
      //
      // **The expected value is spelled out rather than computed from
      // `invitationUrl`.** The first version of this test was
      // `expect(find.textContaining(invitationUrl('tok-42')), findsOneWidget)`,
      // which asserts that the screen shows what `invitationUrl` produces — a
      // statement about nothing at all, true of a function that returned the
      // token on its own. What 5.13 asks is that the link be *derived from
      // `Uri.base`* and *carry the token as a query param*, and both are
      // visible here as literal text.
      //
      // The origin is empty because `Uri.base` is a `file:` URI under
      // `flutter test`, so this asserts the relative form.
      // `invitation_url_test.dart` is where the `http`/`https` branch — the one
      // production runs on — is actually exercised.
      expect(find.text('/register?token=tok-42'), findsOneWidget);
    });

    testWidgets('every invitation gets its own link, and nothing else', (
      tester,
    ) async {
      await openUsers(
        tester,
        userAdapter(
          invitations: invitationsList([
            {
              'invitationId': 1,
              'organizationId': 1,
              'roleId': 2,
              'roleName': 'Volunteer',
              'token': 'token-one',
              'expiresAt': '2026-12-31T00:00:00',
              'createdAt': '2026-10-01T00:00:00',
            },
            {
              'invitationId': 2,
              'organizationId': 1,
              'roleId': 3,
              'roleName': 'Staff',
              'token': 'token-two',
              'expiresAt': '2026-12-31T00:00:00',
              'createdAt': '2026-10-02T00:00:00',
            },
          ]),
        ),
      );

      // `UserList.tsx:157` builds one link per row from that row's token. A
      // single shared `invitationUrl(...)` value reused across rows would give
      // both invitees the same link, and the first one to accept it would
      // consume it.
      expect(find.text('/register?token=token-one'), findsOneWidget);
      expect(find.text('/register?token=token-two'), findsOneWidget);
    });
  });

  group('copy the invite link', () {
    late List<String> clipboard;

    setUp(() {
      clipboard = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard.add((call.arguments as Map)['text'] as String);
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('copies the link and says so for two seconds', (tester) async {
      await openUsers(tester, userAdapter(invitations: invitation()));

      expect(find.text('Copy Link'), findsOneWidget);
      await tester.tap(find.text('Copy Link'));
      await tester.pump();
      await settleRequests(tester);

      expect(clipboard, [invitationUrl('abc123')]);
      expect(find.text('Copied!'), findsOneWidget);

      // `UserList.tsx:160` resets the label after 2000ms. Pumping past it
      // rather than disposing the screen is the point: a timer left pending
      // fires into a disposed state, which is why `_copiedTimer` is cancelled.
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Copied!'), findsNothing);
      expect(find.text('Copy Link'), findsOneWidget);
    });
  });

  group('create an invitation (5.7, and the link half of 5.13)', () {
    /// A backend for this group: [inviteManager] by default, because the form gates
    /// on `MANAGE_INVITATIONS_*` while the button that opens it gates on
    /// `MANAGE_USERS_*`. See [inviteManager].
    StubAdapter inviteAdapter({
      List<String> roles = const ['Organizer', 'Staff'],
      List<String> permissions = inviteManager,
      StubResponse? invitations,
      StubResponse? createInvitationResponse,
    }) => userAdapter(
      permissions: permissions,
      roles: roles,
      invitations: invitations,
      createInvitationResponse: createInvitationResponse,
    );

    /// Opens the inline form and lets it load its roles.
    ///
    /// `UserList.tsx:206` toggles the form in place and there is no route for
    /// it, so it is reached the only way a user reaches it. `settleRequests`
    /// rather than `pumpAndSettle`, because `_load` issues `GET /api/roles` from
    /// `initState` and the screen renders a `CircularProgressIndicator` until
    /// that lands.
    Future<void> openInvitationForm(
      WidgetTester tester,
      StubAdapter adapter, {
      List<String> roles = const ['Organizer', 'Staff'],
    }) async {
      await openUsers(tester, adapter);
      await tester.tap(find.text('Create Invitation'));
      await settleRequests(tester);
      expect(find.text('Select Role:'), findsOneWidget);
      expect(roles, isNotEmpty);
    }

    /// `POST /api/invitations` bodies, decoded.
    List<Map<String, dynamic>> createBodies(StubAdapter adapter) => adapter
        .requests
        .where((o) => o.method == 'POST' && o.path == '/api/invitations')
        .map((o) => jsonDecode(adapter.bodyOf(o)!) as Map<String, dynamic>)
        .toList();

    testWidgets('offers the roles the server sent', (tester) async {
      await openInvitationForm(
        tester,
        inviteAdapter(roles: ['Organizer', 'Staff', 'SuperAdmin']),
      );

      expect(find.widgetWithText(ChoiceChip, 'Organizer'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Staff'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'SuperAdmin'), findsOneWidget);
      // No role is selected on arrival — `CreateInvitationForm.tsx:40` seeds
      // `_selectedRoleId` with null and requires a click.
      expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .every((chip) => !chip.selected),
        isTrue,
      );
    });

    testWidgets('refuses to create anything until a role is picked', (
      tester,
    ) async {
      final adapter = inviteAdapter();
      await openInvitationForm(tester, adapter);

      await tester.tap(find.text('Create Invitation').last);
      await settleRequests(tester);

      // `CreateInvitationForm.tsx:47` — the guard, not a field validator. Note
      // that this is not a `Validators` case: the roles are `ChoiceChip`s, not a
      // form field, so there is nothing for the form convention to attach a
      // message to. It is the one submission guard in Phase 5 that a
      // `TextFormField` validator cannot express.
      expect(find.text('Please select one role.'), findsOneWidget);
      expect(createBodies(adapter), isEmpty);
    });

    testWidgets('sends the picked role and the user\'s own organization', (
      tester,
    ) async {
      final adapter = inviteAdapter();
      await openInvitationForm(tester, adapter);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Staff'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Invitation').last);
      await settleRequests(tester);

      final bodies = createBodies(adapter);
      expect(bodies, hasLength(1));
      // Role 2 of the harness's list, so this distinguishes "the picked role"
      // from "the first role".
      expect(bodies.single['roleId'], 2);
      // `CreateInvitationForm.tsx:59` reads the signed-in user's organization
      // from the context rather than sending the dropdown's value, because a
      // non-global manager is never shown the dropdown. The harness's context
      // user is in organization 1.
      expect(bodies.single['organizationId'], 1);
      // The note is optional and blank, so it goes as an explicit null —
      // `CreateInvitationForm.tsx:71` sends `note || null`, and the port sends
      // the same thing. Asserting on `containsKey` would be the wrong claim
      // here: `json_serializable` includes nulls by default, and the React
      // request had the key too.
      expect(bodies.single['note'], isNull);
    });

    testWidgets('sends a note when one is typed', (tester) async {
      final adapter = inviteAdapter();
      await openInvitationForm(tester, adapter);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Staff'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Note (Optional)'),
        '  Contract reviewer  ',
      );
      await tester.tap(find.text('Create Invitation').last);
      await settleRequests(tester);

      // Trimmed, because `CreateInvitationForm.tsx:71` trims before sending.
      expect(createBodies(adapter).single['note'], 'Contract reviewer');
    });

    testWidgets('the minted link lands in the invitations table, not the form', (
      tester,
    ) async {
      // **This is 5.13's invite-link claim at the widget level**, and the
      // interesting part is *where the link appears*.
      //
      // `CreateInvitationForm` builds the link and hands it to
      // `onInvitationCreated`, and `UserList.tsx:210` responds by closing the
      // form — so the link is never displayed by the form itself. It appears
      // in the invitations table above, which is refetched and now holds the
      // new invitation. A manager mints, the form closes, and the link is
      // sitting in the list with a copy button beside it.
      //
      // The first version of this test asserted the link appeared *in the
      // form*, which is what reading `_handleCreate` alone suggests. It fails,
      // and the failure is the behaviour.
      final adapter = inviteAdapter(
        // The server now lists what it just created — which is what makes
        // "the form closed" and "the link is still on screen" both true.
        invitations: invitationsList([
          {
            'invitationId': 11,
            'organizationId': 1,
            'roleId': 2,
            'roleName': 'Staff',
            'token': 'minted-token',
            'expiresAt': '2026-12-31T00:00:00',
            'createdAt': '2026-10-01T00:00:00',
          },
        ]),
      );
      await openInvitationForm(tester, adapter);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Staff'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Invitation').last);
      await settleRequests(tester);

      // The form is gone, and the link is on the page.
      expect(find.text('Select Role:'), findsNothing);
      expect(find.text('/register?token=minted-token'), findsOneWidget);

      // Parsed, not substring-matched: a link that put the token in the path
      // or the fragment would satisfy a `contains` and be useless to the
      // invitee.
      final shown = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((s) => s.startsWith('/register?token='));
      final parsed = Uri.parse(shown);
      expect(parsed.queryParameters['token'], 'minted-token');
      expect(parsed.path, '/register');
    });

    testWidgets('the link is handed to the screen, which closes the form', (
      tester,
    ) async {
      final adapter = inviteAdapter();
      await openInvitationForm(tester, adapter);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Staff'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Invitation').last);
      await settleRequests(tester);

      // `UserList.tsx:210` calls `onInvitationCreated` and clears the form, so
      // the manager is returned to the list rather than left looking at a link
      // they have to dismiss themselves.
      expect(find.text('Select Role:'), findsNothing);
      // And the invitations table is refetched — the new invitation is
      // outstanding and should be visible without a manual reload.
      expect(invitationRequests(adapter).length, greaterThanOrEqualTo(2));
    });

    testWidgets('refuses SuperAdmin and disables the button', (tester) async {
      final adapter = inviteAdapter(roles: ['Organizer', 'SuperAdmin']);
      await openInvitationForm(tester, adapter);

      await tester.tap(find.widgetWithText(ChoiceChip, 'SuperAdmin'));
      await tester.pumpAndSettle();

      // `CreateInvitationForm.tsx:52-56`. The assertion that matters is the
      // disabled button: the warning is *also* stated in `_handleCreate`, but
      // that copy is unreachable through the UI because the button cannot be
      // pressed. Asserting both messages would pin the second one as live,
      // which it is not — a presence-only check here would be describing a
      // defence that a form that showed the warning and let the request through
      // would also satisfy.
      expect(
        find.textContaining(
          'Invitations can only be created for Organizer or Staff roles',
        ),
        findsOneWidget,
      );
      // Scoped to the form, because the screen's own header has a button with the
      // same label — `find.widgetWithText(FilledButton, 'Create Invitation')`
      // matches both and throws "Bad state: Too many elements".
      final formButton = find.descendant(
        of: find.byType(CreateInvitationForm),
        matching: find.widgetWithText(FilledButton, 'Create Invitation'),
      );
      expect(tester.widget<FilledButton>(formButton).onPressed, isNull);

      // And nothing was sent.
      expect(createBodies(adapter), isEmpty);
    });

    testWidgets('shows the server message and stays open on failure', (
      tester,
    ) async {
      final adapter = inviteAdapter(
        createInvitationResponse: const StubResponse.json(
          '{"success":false,"data":{},'
          '"error":{"message":"Invitation service unavailable"}}',
          status: 500,
        ),
      );
      await openInvitationForm(tester, adapter);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Staff'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Invitation').last);
      await settleRequests(tester);

      expect(find.text('Invitation service unavailable'), findsOneWidget);
      // Still the form, so the manager can retry rather than start over.
      expect(find.text('Select Role:'), findsOneWidget);
      expect(find.text('/register?token=minted-token'), findsNothing);
    });

    testWidgets('the button and the form gate on different permissions', (
      tester,
    ) async {
      // A user manager with no invitation permission gets the button and a
      // refusal, which is what `UserList.tsx:206` does today. Pinned because
      // it is the kind of thing a future "tighten the button's gate" change
      // would silently alter, and because a reader would otherwise assume the
      // two gates were the same set and be wrong.
      final adapter = inviteAdapter(
        permissions: const [viewUsers, manageUsers],
      );
      await openUsers(tester, adapter);
      await tester.tap(find.text('Create Invitation'));
      await settleRequests(tester);

      expect(
        find.text('You do not have permission to create invitations.'),
        findsOneWidget,
      );
      expect(createBodies(adapter), isEmpty);
    });

    testWidgets(
      'a failure to load the roles is reported, not spun on forever',
      (tester) async {
        // `CreateInvitationForm.tsx:44-48` renders `Loading...` for as long as
        // the fetch is outstanding and shows `error` beneath it, so a fetch
        // that never answers leaves a spinner with no way forward. This is the
        // reachable version: the request fails.
        final adapter = contextAdapter(
          permissions: inviteManager,
          rolesResponder: () => const StubResponse.json(
            '{"success":false,"data":{},'
            '"error":{"message":"Role service unavailable"}}',
            status: 500,
          ),
          forOtherRoutes: (options) =>
              options.path == '/api/users' && options.method == 'GET'
              ? usersPage(const ['grace'])
              : options.path == '/api/invitations' && options.method == 'GET'
              ? invitationsList(const [])
              : null,
        );
        await openUsers(tester, adapter);
        await tester.tap(find.text('Create Invitation'));
        await settleRequests(tester);

        expect(find.text('Role service unavailable'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
  });

  group('delete an invitation', () {
    testWidgets(
      'asks first, naming what would break, and cancelling changes nothing',
      (tester) async {
        final adapter = userAdapter(invitations: invitation());
        await openUsers(tester, adapter);

        await tester.tap(invitationRowDelete());
        await tester.pumpAndSettle();

        expect(find.text('Delete invitation'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(adapter.requests.where((o) => o.method == 'DELETE'), isEmpty);
      },
    );

    testWidgets('confirming deletes the invitation and refetches only those', (
      tester,
    ) async {
      final adapter = userAdapter(invitations: invitation());
      await openUsers(tester, adapter);

      await tester.tap(invitationRowDelete());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await settleRequests(tester);

      expect(
        adapter.requests.where((o) => o.method == 'DELETE').map((o) => o.path),
        ['/api/invitations/7'],
      );
      // `UserList.tsx:104` refetched the *invitations*, not the users — the two
      // are independent fetches and deleting a row from one does not change
      // the other. A screen that invalidated both would be hiding a second
      // request behind an unnecessary one.
      expect(invitationRequests(adapter), hasLength(2));
      expect(userRequests(adapter), hasLength(1));
    });
  });

  group('delete a user', () {
    testWidgets(
      'asks first, naming the record, and cancelling changes nothing',
      (tester) async {
        final adapter = userAdapter();
        await openUsers(tester, adapter);
        await hoverRow(tester, 'grace');

        await tester.tap(userRowDelete().first);
        await tester.pumpAndSettle();

        expect(find.text('Delete user'), findsOneWidget);
        // `window.confirm` did not say which user; this does.
        expect(find.textContaining('grace'), findsWidgets);

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(adapter.requests.where((o) => o.method == 'DELETE'), isEmpty);
      },
    );

    testWidgets(
      'it calls an endpoint that does not exist, and shows the failure',
      (tester) async {
        final adapter = userAdapter();
        await openUsers(tester, adapter);
        await hoverRow(tester, 'grace');

        await tester.tap(userRowDelete().first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await settleRequests(tester);

        // The request is made, exactly as `UserList.tsx:81` made it.
        expect(
          adapter.requests
              .where((o) => o.method == 'DELETE')
              .map((o) => o.path),
          ['/api/users/1'],
        );
        // And it 404s, because `UserRoutes.kt` defines no `delete` route. The
        // React original caught that failure and put it in the shared `error`
        // state the table rendered; the ported screen shows it in the action
        // banner. **This test is the reproduction of task 10.12** — when the
        // endpoint lands it will fail here, which is the intended signal.
        expect(find.textContaining('API endpoint not found'), findsOneWidget);
        // The list is untouched, because nothing was deleted.
        expect(userRequests(adapter), hasLength(1));
      },
      skip: kIsWeb,
    );
  });

  group('cards at mobile', () {
    testWidgets('a narrow viewport renders cards, not tables', (tester) async {
      await openUsers(
        tester,
        userAdapter(usernames: const ['grace'], invitations: invitation()),
        width: 500,
      );

      expect(find.byType(Table), findsNothing);
      expect(find.text('grace'), findsOneWidget);
      expect(find.text('Volunteer'), findsOneWidget);
      // Actions are always visible in a card — there is no hover to reveal
      // them on a touch device (task 4.2). Two delete buttons, because both
      // tables card-ify and each has one; only the users' row has an edit,
      // since `UserList.tsx:186` gives invitations a delete and nothing else.
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsNWidgets(2));
    });
  });
}
