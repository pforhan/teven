import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/routing/app_router.dart';
import 'package:teven_app/screens/customers/customer_details_screen.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

/// The customer details screen — task 9.0's sweep.
///
/// The read-only page the customer list's name links land on, and the edit
/// affordance that leads onward to the edit screen.
void main() {
  const viewCustomers = 'VIEW_CUSTOMERS_ORGANIZATION';
  const manageCustomers = 'MANAGE_CUSTOMERS_ORGANIZATION';

  /// Opens `/customers/42` — the id the stubbed backend answers every customer
  /// lookup with.
  Future<ProviderContainer> openCustomerDetails(
    WidgetTester tester,
    StubAdapter adapter,
  ) async {
    final container = await pumpApp(
      tester,
      width: 1500.0,
      token: 'token',
      adapter: adapter,
    );
    await goTo(tester, container, '/customers/42');
    return container;
  }

  group('rendering', () {
    testWidgets('shows the customer the server returned', (tester) async {
      final adapter = contextAdapter(
        permissions: [viewCustomers],
        forOtherRoutes: (options) => options.path == '/api/customers/42'
            ? const StubResponse.json(
                '{"success":true,"data":{"customerId":42,"name":"Acme",'
                '"phone":"555-0100","address":"1 Main St","notes":"",'
                '"organization":{"organizationId":1,"name":"Acme",'
                '"contactInformation":""}}}',
              )
            : null,
      );
      await openCustomerDetails(tester, adapter);

      expect(find.byType(CustomerDetailsScreen), findsOneWidget);
      expect(find.text('Customer Details'), findsOneWidget);
      expect(find.text('Name: Acme'), findsOneWidget);
      expect(find.text('Phone: 555-0100'), findsOneWidget);
      expect(find.text('Address: 1 Main St'), findsOneWidget);
      // The notes field is part of the record, and reads back as written.
      expect(find.text('Notes: '), findsOneWidget);
    });

    testWidgets('a failure shows the server message rather than spinning on', (
      tester,
    ) async {
      // A hand-rolled adapter rather than [contextAdapter]: the shared one
      // answers *every* `/api/customers/{id}` lookup, and the only way to make
      // this screen's own fetch fail is to answer this one differently. The
      // context, the initial location's events calls and the rest keep their
      // canned answers, so the test fails on the screen rather than on the
      // boot sequence.
      final adapter = StubAdapter((options) {
        if (options.path == '/api/users/context') {
          return StubResponse.json(
            userContextJson(permissions: [viewCustomers]),
          );
        }
        if (options.method == 'GET' &&
            options.path.startsWith('/api/customers/')) {
          return const StubResponse.json(
            '{"success":false,"data":{},'
            '"error":{"message":"Customer service unavailable"}}',
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

      await openCustomerDetails(tester, adapter);

      expect(find.text('Error: Customer service unavailable'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('the edit affordance', () {
    testWidgets(
      'an organization-scoped manager gets an edit button that opens the edit screen',
      (tester) async {
        final adapter = contextAdapter(
          permissions: [viewCustomers, manageCustomers],
          forOtherRoutes: (options) => options.path == '/api/customers/42'
              ? const StubResponse.json(
                  '{"success":true,"data":{"customerId":42,"name":"Acme",'
                  '"phone":"555-0100","address":"1 Main St","notes":"",'
                  '"organization":{"organizationId":1,"name":"Acme",'
                  '"contactInformation":""}}}',
                )
              : null,
        );
        final container = await openCustomerDetails(tester, adapter);

        expect(find.text('Edit'), findsOneWidget);
        await tester.tap(find.text('Edit'));
        await settleRequests(tester);

        expect(currentPath(container), AppRoutes.customerEditPath(42));
      },
    );

    testWidgets('a viewer without manage rights gets no edit button', (
      tester,
    ) async {
      final adapter = contextAdapter(
        permissions: [viewCustomers],
        forOtherRoutes: (options) => options.path == '/api/customers/42'
            ? const StubResponse.json(
                '{"success":true,"data":{"customerId":42,"name":"Acme",'
                '"phone":"555-0100","address":"1 Main St","notes":"",'
                '"organization":{"organizationId":1,"name":"Acme",'
                '"contactInformation":""}}}',
              )
            : null,
      );
      await openCustomerDetails(tester, adapter);

      expect(find.text('Edit'), findsNothing);
    });
  });
}
