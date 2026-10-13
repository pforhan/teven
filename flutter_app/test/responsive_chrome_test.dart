import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/core/layout/breakpoints.dart';
import 'package:teven_app/providers/organization_controller.dart';
import 'package:teven_app/routing/app_router.dart';

import 'support/auth_harness.dart';

/// The responsive chrome — tasks 3.1 through 3.11 and 3.13.
///
/// Sizes are pinned rather than exercised in a real browser. Task 3.12 stays as
/// the manual pass; what these tests establish is that the *branch* is chosen
/// from the available width and that each branch renders the right controls,
/// which is the part a browser check would not catch anyway.
///
/// Most cases run at [mobileWidth] and open the drawer, because a drawer is a
/// flat vertical list: one `find.text` per assertion, no `NavigationRail`
/// internals to know about. The rail cases are the exception and assert on the
/// rail's own properties.
void main() {
  const mobileWidth = 500.0;
  const tabletWidth = 900.0;
  const desktopWidth = 1300.0;

  const viewEvents = 'VIEW_EVENTS_ORGANIZATION';
  const viewCustomers = 'VIEW_CUSTOMERS_ORGANIZATION';
  const viewInventory = 'VIEW_INVENTORY_ORGANIZATION';
  const viewReports = 'VIEW_REPORTS_ORGANIZATION';
  const viewOrganizations = 'VIEW_ORGANIZATIONS_GLOBAL';
  const viewUsersOrg = 'VIEW_USERS_ORGANIZATION';
  const viewUsersGlobal = 'VIEW_USERS_GLOBAL';

  /// Every permission the nav items check for, so one grant shows all six.
  const allNavPermissions = [
    viewEvents,
    viewCustomers,
    viewInventory,
    viewReports,
    viewOrganizations,
    viewUsersOrg,
  ];

  Future<ProviderContainer> pumpAt(
    WidgetTester tester,
    double width, {
    List<String> permissions = const [viewEvents],
    Map<String, Object> prefs = const {},
  }) => pumpApp(
    tester,
    width: width,
    token: 'token',
    prefs: prefs,
    adapter: contextAdapter(permissions: permissions),
  );

  /// Opens the mobile drawer and settles.
  Future<void> openDrawer(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
  }

  NavigationRail railIn(WidgetTester tester) =>
      tester.widget<NavigationRail>(find.byType(NavigationRail));

  group('breakpoints', () {
    // Task 3.2. The thresholds are this app's, so they are asserted directly
    // rather than only through the widget — a wrong number here would still
    // produce a passing widget test at every width.
    test('classify widths at and around each threshold', () {
      expect(AppBreakpoints.of(0), LayoutSize.mobile);
      expect(AppBreakpoints.of(mobileWidth), LayoutSize.mobile);
      expect(AppBreakpoints.of(699.9), LayoutSize.mobile);

      expect(AppBreakpoints.of(AppBreakpoints.tablet), LayoutSize.tablet);
      expect(AppBreakpoints.of(tabletWidth), LayoutSize.tablet);
      expect(AppBreakpoints.of(1099.9), LayoutSize.tablet);

      expect(AppBreakpoints.of(AppBreakpoints.desktop), LayoutSize.desktop);
      expect(AppBreakpoints.of(desktopWidth), LayoutSize.desktop);
    });
  });

  group('chrome per breakpoint', () {
    // Task 3.3.
    testWidgets('mobile is an app bar and a drawer, with no rail', (
      tester,
    ) async {
      await pumpAt(tester, mobileWidth);

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationDrawer), findsNothing, reason: 'closed');

      await openDrawer(tester);
      expect(find.byType(NavigationDrawer), findsOneWidget);
    });

    testWidgets('tablet is a collapsed rail', (tester) async {
      await pumpAt(tester, tabletWidth);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(railIn(tester).extended, isFalse);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('desktop is an extended rail', (tester) async {
      await pumpAt(tester, desktopWidth);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(railIn(tester).extended, isTrue);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('a resize moves between layouts without a rebuild of the app', (
      tester,
    ) async {
      // The reason task 3.2 says `LayoutBuilder`: the branch has to follow the
      // window, not the device. A device check would stay on the rail after
      // the browser is narrowed.
      final container = await pumpAt(tester, desktopWidth);
      expect(find.byType(NavigationRail), findsOneWidget);

      tester.view.physicalSize = const Size(mobileWidth, 900);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
      expect(currentPath(container), AppRoutes.events);
    });
  });

  group('nav items are permission-gated', () {
    // Task 3.4. `MainLayout.tsx:22-27` wraps each `<li>` in its own test, so
    // an item the user cannot reach is absent rather than disabled.
    testWidgets('only the granted items appear', (tester) async {
      await pumpAt(
        tester,
        mobileWidth,
        permissions: const [viewEvents, viewReports],
      );
      await openDrawer(tester);

      expect(find.text('Events'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Customers'), findsNothing);
      expect(find.text('Inventory'), findsNothing);
      expect(find.text('Organizations'), findsNothing);
      expect(find.text('Users'), findsNothing);
    });

    testWidgets('a user with no permissions gets no navigation at all', (
      tester,
    ) async {
      await pumpAt(tester, mobileWidth, permissions: const []);
      await openDrawer(tester);

      for (final label in ['Events', 'Customers', 'Inventory', 'Reports']) {
        expect(find.text(label), findsNothing, reason: label);
      }
      // Profile and Logout are not gated, and must survive an empty set —
      // otherwise a user with no grants has no way out of the app.
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets('Users is shown for either scope', (tester) async {
      // `MainLayout.tsx:27` is the one OR-gated item. One case per scope: the
      // failure mode of getting it wrong — a global admin who cannot reach the
      // Users screen they are the only people who can administer — is silent.
      for (final permission in const [viewUsersOrg, viewUsersGlobal]) {
        await pumpAt(tester, mobileWidth, permissions: [permission]);
        await openDrawer(tester);

        expect(find.text('Users'), findsOneWidget, reason: permission);
      }
    });

    testWidgets('all six appear with the full set', (tester) async {
      await pumpAt(tester, mobileWidth, permissions: allNavPermissions);
      await openDrawer(tester);

      for (final label in const [
        'Events',
        'Customers',
        'Inventory',
        'Reports',
        'Organizations',
        'Users',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });
  });

  group('navigation', () {
    testWidgets('a rail destination navigates', (tester) async {
      final container = await pumpAt(
        tester,
        tabletWidth,
        permissions: const [viewEvents, viewCustomers],
      );

      await tester.tap(find.text('Customers'));
      await tester.pumpAndSettle();

      expect(currentPath(container), AppRoutes.customers);
    });

    testWidgets('a drawer destination navigates and closes the drawer', (
      tester,
    ) async {
      final container = await pumpAt(
        tester,
        mobileWidth,
        permissions: const [viewEvents, viewCustomers],
      );
      await openDrawer(tester);

      await tester.tap(find.text('Customers'));
      await tester.pumpAndSettle();

      expect(currentPath(container), AppRoutes.customers);
      // Closing first and navigating second — the other order leaves the
      // drawer's scrim over the new screen swallowing the next tap.
      expect(find.byType(NavigationDrawer), findsNothing);
    });

    testWidgets('a nested path still selects its section', (tester) async {
      // `/events/42` is not equal to `/events`, but it renders inside the Events
      // item. An equality match would select nothing.
      final container = await pumpAt(
        tester,
        tabletWidth,
        permissions: allNavPermissions,
      );

      await goTo(tester, container, '/events/42');

      expect(railIn(tester).selectedIndex, 0);
    });

    testWidgets('the session controls sit at the foot of the rail', (
      tester,
    ) async {
      // A presence-only test cannot see this. `NavigationRail` gives its
      // trailing slot an `Expanded`, but a `MainAxisSize.min` column inside it
      // still hugs the *top* — so Profile and Logout rendered directly beneath
      // the destinations instead of at the bottom, which is where
      // `MainLayout.tsx:29-41` puts them. Every assertion above passed with the
      // bug present; only a rendered screenshot showed it.
      await pumpAt(tester, tabletWidth, permissions: allNavPermissions);

      final railBottom = tester.getBottomLeft(find.byType(NavigationRail)).dy;
      final logoutBottom = tester.getBottomLeft(find.byIcon(Icons.logout)).dy;
      final destinationsTop = tester.getTopLeft(find.byType(NavigationRail)).dy;

      expect(
        logoutBottom,
        greaterThan(railBottom - 100),
        reason: 'Logout should hug the bottom of the rail',
      );
      expect(
        logoutBottom,
        greaterThan(destinationsTop + 400),
        reason: '...and be well clear of the destinations',
      );
    });
  });

  group('session controls', () {
    // Task 3.9.
    testWidgets('Profile navigates', (tester) async {
      final container = await pumpAt(tester, tabletWidth);

      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      expect(currentPath(container), AppRoutes.profile);
    });

    testWidgets('Logout returns to /login', (tester) async {
      final container = await pumpAt(tester, mobileWidth);
      await openDrawer(tester);

      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      // No navigation is performed by the button itself; clearing the context
      // is enough, and the router's redirect does the rest.
      expect(currentPath(container), AppRoutes.login);
    });
  });

  group('organization control', () {
    // Tasks 3.5, 3.6 and 3.8.
    testWidgets('a non-super-admin sees a static organization name', (
      tester,
    ) async {
      await pumpAt(tester, desktopWidth, permissions: const [viewEvents]);

      // `MainLayout.tsx:36` — the user's own organization from the context.
      expect(find.text('Acme'), findsOneWidget);
      expect(find.text('All Organizations'), findsNothing);
    });

    testWidgets('a super-admin gets the switcher', (tester) async {
      // `VIEW_USERS_GLOBAL` is what derives `isSuperAdmin` (`MainLayout.tsx:10`).
      await pumpAt(tester, desktopWidth, permissions: const [viewUsersGlobal]);

      expect(find.text('All Organizations'), findsOneWidget);
      expect(find.text('Acme'), findsNothing, reason: 'not the context org');
    });

    testWidgets('the switcher remembers a selection across a reload', (
      tester,
    ) async {
      // The persistence is task 2.4's, but the control is the only thing that
      // reads it — so without this the restored value would never be
      // observable and the store would look like dead code.
      const stored =
          '{"organizationId":2,"name":"Globex","contactInformation":""}';

      await pumpAt(
        tester,
        desktopWidth,
        permissions: const [viewUsersGlobal],
        prefs: {OrganizationController.storageKey: stored},
      );

      expect(find.text('Globex'), findsOneWidget);
    });
  });
}
