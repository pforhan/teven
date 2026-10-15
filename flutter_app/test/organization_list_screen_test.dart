import 'dart:convert';

import 'package:dio/dio.dart' show RequestOptions;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/models/organization.dart';
import 'package:teven_app/routing/app_router.dart';
import 'package:teven_app/screens/organizations/organization_list_screen.dart';
import 'package:teven_app/widgets/responsive_list_view.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

/// The organization list — task 4.6, and the organization half of the delete
/// confirmation in 4.8.
///
/// The interesting case here is not the rendering, which the customer and
/// inventory screens already pin; it is that this screen is **global** while
/// every other list in the app is scoped to the selected organization. The
/// `scoping` group below is where that is pinned, because it is the one thing
/// here that a copy of either other screen would get wrong.
void main() {
  /// Wide enough for the extended rail (256) *and* a table (1100) beside it.
  const desktopWidth = 1500.0;
  const viewOrganizations = 'VIEW_ORGANIZATIONS_GLOBAL';
  const manageOrganizations = 'MANAGE_ORGANIZATIONS_GLOBAL';

  StubResponse organizationsPage(List<String> names) => StubResponse.json(
    jsonEncode({
      'success': true,
      'data': {
        'items': [
          for (var i = 0; i < names.length; i++)
            {
              'organizationId': i + 1,
              'name': names[i],
              'contactInformation': 'contact-${i + 1}@example.com',
            },
        ],
        'total': names.length,
        'limit': 25,
        'offset': 0,
      },
    }),
  );

  /// The screen's own adapter.
  ///
  /// `/api/organizations` needs [contextAdapter]'s `organizationsResponder`
  /// rather than `forOtherRoutes`: the harness answers that path for the
  /// chrome's switcher *before* consulting `forOtherRoutes`, so the first
  /// version of this file stubbed the screen's endpoint and watched the screen
  /// render the harness's own two organizations anyway — including in the case
  /// that stubs a *failure*, which then showed nothing at all.
  ///
  /// The names avoid "Acme", which the chrome puts on screen as the signed-in
  /// user's own organization, so `find.text('Acme')` would match twice.
  StubAdapter organizationAdapter({
    List<String> names = const ['Initech', 'Hooli'],
    List<String> permissions = const [viewOrganizations, manageOrganizations],
    StubResponse? failure,
  }) => contextAdapter(
    permissions: permissions,
    organizationsResponder: (_) => failure ?? organizationsPage(names),
    forOtherRoutes: (options) {
      if (options.method == 'DELETE') {
        return const StubResponse.noContent();
      }
      return null;
    },
  );

  Future<ProviderContainer> openOrganizations(
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
    await goToAndLoad(tester, container, AppRoutes.organizations);
    return container;
  }

  /// `GET /api/organizations` requests the screen made, as opposed to the
  /// chrome's — distinguished by the limit each asks for.
  List<RequestOptions> screenRequests(StubAdapter adapter) => adapter.requests
      .where(
        (o) =>
            o.path == '/api/organizations' &&
            o.method == 'GET' &&
            o.queryParameters['limit'] == 25,
      )
      .toList();

  Future<void> hoverFirstRow(WidgetTester tester) async {
    final row = find.text('Initech');
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(row));
    await gesture.moveTo(tester.getCenter(row));
    await tester.pumpAndSettle();
  }

  group('rendering', () {
    testWidgets('shows the organizations the server returned', (tester) async {
      await openOrganizations(tester, organizationAdapter());

      expect(find.byType(OrganizationListScreen), findsOneWidget);
      expect(
        find.byType(ResponsiveListView<OrganizationResponse>),
        findsOneWidget,
      );
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('Initech'), findsOneWidget);
      expect(find.text('Hooli'), findsOneWidget);
      expect(find.text('contact-1@example.com'), findsOneWidget);
    });

    testWidgets('is no longer a placeholder', (tester) async {
      await openOrganizations(tester, organizationAdapter());

      expect(
        find.text('Not ported yet — see FLUTTER-CONVERT.md.'),
        findsNothing,
      );
    });

    testWidgets('queries with the original limit, sort and offset', (
      tester,
    ) async {
      final adapter = organizationAdapter();
      await openOrganizations(tester, adapter);

      final request = screenRequests(adapter).single;
      expect(request.queryParameters['limit'], 25);
      expect(request.queryParameters['offset'], 0);
      expect(request.queryParameters['sortBy'], 'name');
      expect(request.queryParameters['sortOrder'], 'asc');
      expect(request.queryParameters.containsKey('search'), isFalse);
    });

    testWidgets(
      'a failure shows the server message',
      (tester) async {
        await openOrganizations(
          tester,
          organizationAdapter(
            failure: const StubResponse.json(
              '{"success":false,"data":{},'
              '"error":{"message":"Organization service unavailable"}}',
              status: 500,
            ),
          ),
        );

        expect(
          find.text('Error: Organization service unavailable'),
          findsOneWidget,
        );
      },
      // Skipped on web for the reason recorded on the customer screen's
      // matching test: rendering `ErrorDisplay` after a rejected request ends
      // in a silent pending-timer teardown on Chrome, which is the unowned gap
      // the Phase 3 log flagged rather than a defect in this screen.
      skip: kIsWeb,
    );
  });

  group('scoping', () {
    testWidgets('is not scoped to the selected organization', (tester) async {
      final adapter = organizationAdapter();
      await openOrganizations(
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

      // **The one thing this screen does that no other list does.**
      // `CustomerList.tsx` and `InventoryList.tsx` both pass
      // `selectedOrganization?.organizationId` to narrow their results, and a
      // copy of either would narrow this one too. That would hide every
      // organization but one from the screen whose whole job is to show all
      // of them. `OrganizationList.tsx:26-31` sends five parameters and no
      // organization, so this sends five and none.
      expect(
        screenRequests(adapter).last.queryParameters
            .containsKey('organizationId'),
        isFalse,
      );
      // Both rows are on screen, which is the observable consequence.
      expect(find.text('Initech'), findsOneWidget);
      expect(find.text('Hooli'), findsOneWidget);
    });
  });

  group('permissions', () {
    testWidgets('the route is closed without VIEW_ORGANIZATIONS_GLOBAL', (
      tester,
    ) async {
      final container = await pumpApp(
        tester,
        width: desktopWidth,
        token: 'token',
        // View customers, which is enough to be signed in and nothing else.
        adapter: organizationAdapter(
          permissions: const ['VIEW_EVENTS_ORGANIZATION'],
        ),
      );

      final landed = await goToAndLoad(
        tester,
        container,
        AppRoutes.organizations,
      );

      // `ProtectedRoute.tsx:27` sends an unauthorized user to `/events`, and
      // this user holds the permission that route needs — so the fallback is
      // not itself another redirect loop.
      expect(landed, AppRoutes.events);
      expect(find.byType(OrganizationListScreen), findsNothing);
    });

    testWidgets('a viewer gets no create button and no row actions', (
      tester,
    ) async {
      await openOrganizations(
        tester,
        organizationAdapter(permissions: const [viewOrganizations]),
      );

      expect(find.text('Create Organization'), findsNothing);

      await hoverFirstRow(tester);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
      // The data is still there — the gate is on the actions, not the screen.
      expect(find.text('Initech'), findsOneWidget);
    });

    testWidgets('a manager gets both', (tester) async {
      await openOrganizations(tester, organizationAdapter());

      expect(find.text('Create Organization'), findsOneWidget);

      await hoverFirstRow(tester);
      expect(find.byIcon(Icons.edit), findsWidgets);
      expect(find.byIcon(Icons.delete), findsWidgets);
    });
  });

  group('delete', () {
    testWidgets(
      'asks first, naming the record, and cancelling changes nothing',
      (tester) async {
        final adapter = organizationAdapter();
        await openOrganizations(tester, adapter);
        await hoverFirstRow(tester);

        await tester.tap(find.byIcon(Icons.delete).first);
        await tester.pumpAndSettle();

        expect(find.text('Delete organization'), findsOneWidget);
        // `window.confirm` did not say which organization; this does.
        expect(find.textContaining('Initech'), findsWidgets);

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(adapter.requests.where((o) => o.method == 'DELETE'), isEmpty);
        expect(find.text('Delete organization'), findsNothing);
      },
    );

    testWidgets('confirming deletes and refetches', (tester) async {
      final adapter = organizationAdapter();
      await openOrganizations(tester, adapter);
      await hoverFirstRow(tester);

      await tester.tap(find.byIcon(Icons.delete).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await settleRequests(tester);

      expect(
        adapter.requests.where((o) => o.method == 'DELETE').map((o) => o.path),
        ['/api/organizations/1'],
      );
      // `OrganizationList.tsx:54` re-fetched after deleting.
      expect(screenRequests(adapter), hasLength(2));
    });
  });

  group('sorting', () {
    testWidgets('a second tap on the name column reverses it', (tester) async {
      final adapter = organizationAdapter();
      await openOrganizations(tester, adapter);

      await tester.tap(find.text('Name'));
      await settleRequests(tester);
      expect(
        screenRequests(adapter).map((r) => r.queryParameters['sortOrder']),
        ['asc', 'desc'],
      );
    });

    testWidgets('only the name column is sortable, as in the original', (
      tester,
    ) async {
      final adapter = organizationAdapter();
      await openOrganizations(tester, adapter);

      // `OrganizationList.tsx:94` marks `contactInformation` not sortable,
      // and `OrganizationDao` agrees — its `when` handles `name` and falls
      // through to `id`. So here the client and the server happen to match;
      // the customer screen's `sortBy` for phone is honoured by `CustomerDao`
      // and absent from the UI, which is the more interesting mismatch.
      await tester.tap(find.text('Contact Information'));
      await settleRequests(tester);

      expect(screenRequests(adapter).map((r) => r.queryParameters['sortBy']), [
        'name',
      ]);
    });
  });

  group('cards at mobile', () {
    testWidgets('a narrow viewport renders cards, not a table', (tester) async {
      await openOrganizations(
        tester,
        organizationAdapter(names: const ['Initech']),
        width: 500,
      );

      expect(find.byType(Table), findsNothing);
      expect(find.text('Initech'), findsOneWidget);
      expect(find.text('contact-1@example.com'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });
  });
}
