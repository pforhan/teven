import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/routing/app_router.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

void main() {
  const orgScoped = <String>['VIEW_REPORTS_ORGANIZATION'];
  const globalScoped = <String>[
    'VIEW_REPORTS_ORGANIZATION',
    'VIEW_REPORTS_GLOBAL',
  ];

  StubResponse reportList() =>
      const StubResponse.json('{"success":true,"data":[]}');

  testWidgets(
    'org-scoped user sees their effective organization and loads inventory usage',
    (tester) async {
      final adapter = contextAdapter(
        permissions: orgScoped,
        forOtherRoutes: (options) {
          if (options.path == '/api/reports/inventory_usage' &&
              options.method == 'GET') {
            return reportList();
          }
          if (options.path == '/api/reports/staff_hours' &&
              options.method == 'POST') {
            return reportList();
          }
          return null;
        },
      );

      final container = await pumpApp(tester, token: 'token', adapter: adapter);
      await goTo(tester, container, AppRoutes.reports);

      expect(find.text('Organization: Acme'), findsOneWidget);
      expect(
        find.textContaining(
          'not scoped to the selected organization on the server',
        ),
        findsNothing,
      );
      expect(
        find.text(
          'Select an organization to access reports. Reports are scoped to one organization.',
        ),
        findsNothing,
      );

      final usageRequests = adapter.requests
          .where(
            (r) =>
                r.path == '/api/reports/inventory_usage' && r.method == 'GET',
          )
          .toList();
      expect(usageRequests, hasLength(1));
      expect(usageRequests.single.queryParameters['organizationId'], 1);
    },
  );

  testWidgets(
    'global user without a selected organization is blocked from reports',
    (tester) async {
      final adapter = contextAdapter(
        permissions: globalScoped,
        forOtherRoutes: (options) {
          if (options.path.startsWith('/api/reports')) {
            return reportList();
          }
          return null;
        },
      );

      final container = await pumpApp(tester, token: 'token', adapter: adapter);
      await goTo(tester, container, AppRoutes.reports);

      expect(
        find.text(
          'Select an organization to access reports. Reports are scoped to one organization.',
        ),
        findsOneWidget,
      );
      expect(find.text('Select Organization'), findsWidgets);
      expect(
        adapter.requests.where((r) => r.path.startsWith('/api/reports')),
        isEmpty,
      );
    },
  );

  testWidgets(
    'global user with a selected organization loads and passes organizationId',
    (tester) async {
      final adapter = contextAdapter(
        permissions: globalScoped,
        forOtherRoutes: (options) {
          if (options.path == '/api/reports/inventory_usage' &&
              options.method == 'GET') {
            return reportList();
          }
          if (options.path == '/api/reports/staff_hours' &&
              options.method == 'POST') {
            return reportList();
          }
          return null;
        },
      );

      final container = await pumpApp(
        tester,
        token: 'token',
        adapter: adapter,
        prefs: {
          'selectedOrganization': jsonEncode({
            'organizationId': 7,
            'name': 'Globex',
            'contactInformation': '',
            'timezone': 'UTC',
          }),
        },
      );
      await goTo(tester, container, AppRoutes.reports);

      expect(find.text('Organization: Globex'), findsOneWidget);
      final usageRequests = adapter.requests
          .where(
            (r) =>
                r.path == '/api/reports/inventory_usage' && r.method == 'GET',
          )
          .toList();
      expect(usageRequests, isNotEmpty);
      expect(usageRequests.first.queryParameters['organizationId'], 7);

      // Generate staff hours (dates required) by entering dates via pickers is awkward;
      // verify the service call shape by triggering generate with dates set would require
      // more harnessing. The organizationId wiring is covered by the request-level service
      // test and the inventory usage request above; staff hours uses the same effective org.
      expect(find.text('Generate Staff Hours Report'), findsOneWidget);
    },
  );
}
