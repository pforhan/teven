import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/routing/app_router.dart';
import 'package:teven_app/screens/inventory/inventory_details_screen.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

/// The inventory details screen sweep.
///
/// The read-only page the inventory list's name links land on, and the edit
/// affordance that leads onward to the edit screen.
void main() {
  const viewInventory = 'VIEW_INVENTORY_ORGANIZATION';
  const manageInventory = 'MANAGE_INVENTORY_ORGANIZATION';
  const viewEvents = 'VIEW_EVENTS_ORGANIZATION';

  /// Opens `/inventory/42` — the id the stubbed backend answers every inventory
  /// lookup with.
  Future<ProviderContainer> openInventoryDetails(
    WidgetTester tester,
    StubAdapter adapter,
  ) async {
    final container = await pumpApp(
      tester,
      width: 1500.0,
      token: 'token',
      adapter: adapter,
    );
    await goTo(tester, container, '/inventory/42');
    return container;
  }

  group('rendering', () {
    testWidgets('shows the inventory the server returned', (tester) async {
      final adapter = contextAdapter(
        permissions: [viewInventory],
        forOtherRoutes: (options) => options.path == '/api/inventory/42'
            ? const StubResponse.json(
                '{"success":true,"data":{"inventoryId":42,"name":"Nails",'
                '"description":"Box of nails","quantity":3,"events":[],'
                '"organization":{"organizationId":1,"name":"Acme",'
                '"contactInformation":"","timezone":"UTC"}}}',
              )
            : null,
      );
      await openInventoryDetails(tester, adapter);

      expect(find.byType(InventoryDetailsScreen), findsOneWidget);
      expect(find.text('Inventory Details'), findsOneWidget);
      expect(find.text('Name: Nails'), findsOneWidget);
      expect(find.text('Description: Box of nails'), findsOneWidget);
      expect(find.text('Quantity: 3'), findsOneWidget);
    });

    testWidgets('shows today and upcoming events for the inventory item', (
      tester,
    ) async {
      final adapter = contextAdapter(
        permissions: [viewInventory],
        forOtherRoutes: (options) {
          if (options.path == '/api/inventory/42') {
            return const StubResponse.json(
              '{"success":true,"data":{"inventoryId":42,"name":"Nails",'
              '"description":"Box of nails","quantity":3,"events":[],'
              '"organization":{"organizationId":1,"name":"Acme",'
              '"contactInformation":"","timezone":"UTC"}}}',
            );
          }
          if (options.method == 'GET' &&
              options.path == '/api/events' &&
              options.queryParameters['inventoryId']?.toString() == '42') {
            return const StubResponse.json(
              '{"success":true,"data":{"items":[{"eventId":7,'
              '"title":"Build Day","startsAt":"2026-11-24T09:00:00Z",'
              '"timezone":"UTC","durationMinutes":60,"location":null,'
              '"latitude":null,"longitude":null,"formattedAddress":null,'
              '"description":null,"inventoryItems":[],"customer":null,'
              '"rsvps":[],"organization":{"organizationId":1,"name":"Acme",'
              '"contactInformation":"","timezone":"UTC"},'
              '"openInvitation":false,"numberOfStaffNeeded":0}],'
              '"total":1,"limit":25,"offset":0}}',
            );
          }
          return null;
        },
      );
      await openInventoryDetails(tester, adapter);

      expect(find.text('Today and upcoming events'), findsOneWidget);
      expect(find.text('Build Day'), findsOneWidget);
      expect(find.text('View all events'), findsOneWidget);
    });

    testWidgets('View all events links to the filtered event list', (
      tester,
    ) async {
      final adapter = contextAdapter(
        permissions: [viewInventory, viewEvents],
        forOtherRoutes: (options) {
          if (options.path == '/api/inventory/42') {
            return const StubResponse.json(
              '{"success":true,"data":{"inventoryId":42,"name":"Nails",'
              '"description":"Box of nails","quantity":3,"events":[],'
              '"organization":{"organizationId":1,"name":"Acme",'
              '"contactInformation":"","timezone":"UTC"}}}',
            );
          }
          if (options.method == 'GET' &&
              options.path == '/api/events' &&
              options.queryParameters['inventoryId']?.toString() == '42') {
            return const StubResponse.json(
              '{"success":true,"data":{"items":[],"total":0,"limit":25,"offset":0}}',
            );
          }
          return null;
        },
      );
      final container = await openInventoryDetails(tester, adapter);

      await tester.tap(find.text('View all events'));
      await settleRequests(tester);

      expect(
        currentLocation(container),
        AppRoutes.eventListPath(inventoryId: 42),
      );
    });

    testWidgets('a failure shows the server message rather than spinning on', (
      tester,
    ) async {
      // A hand-rolled adapter rather than [contextAdapter]: the shared one
      // answers *every* `/api/inventory/{id}` lookup, and the only way to make
      // this screen's own fetch fail is to answer this one differently. The
      // context, the initial location's events calls and the rest keep their
      // canned answers, so the test fails on the screen rather than on the
      // boot sequence.
      final adapter = StubAdapter((options) {
        if (options.path == '/api/users/context') {
          return StubResponse.json(
            userContextJson(permissions: [viewInventory]),
          );
        }
        if (options.method == 'GET' &&
            options.path.startsWith('/api/inventory/')) {
          return const StubResponse.json(
            '{"success":false,"data":{},'
            '"error":{"message":"Inventory service unavailable"}}',
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

      await openInventoryDetails(tester, adapter);

      expect(find.text('Error: Inventory service unavailable'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('the edit affordance', () {
    testWidgets(
      'an organization-scoped manager gets an edit button that opens the edit screen',
      (tester) async {
        final adapter = contextAdapter(
          permissions: [viewInventory, manageInventory],
          forOtherRoutes: (options) => options.path == '/api/inventory/42'
              ? const StubResponse.json(
                  '{"success":true,"data":{"inventoryId":42,"name":"Nails",'
                  '"description":"Box of nails","quantity":3,"events":[],'
                  '"organization":{"organizationId":1,"name":"Acme",'
                  '"contactInformation":"","timezone":"UTC"}}}',
                )
              : null,
        );
        final container = await openInventoryDetails(tester, adapter);

        expect(find.text('Edit'), findsOneWidget);
        await tester.tap(find.text('Edit'));
        await settleRequests(tester);

        expect(currentPath(container), AppRoutes.inventoryEditPath(42));
      },
    );

    testWidgets('a viewer without manage rights gets no edit button', (
      tester,
    ) async {
      final adapter = contextAdapter(
        permissions: [viewInventory],
        forOtherRoutes: (options) => options.path == '/api/inventory/42'
            ? const StubResponse.json(
                '{"success":true,"data":{"inventoryId":42,"name":"Nails",'
                '"description":"Box of nails","quantity":3,"events":[],'
                '"organization":{"organizationId":1,"name":"Acme",'
                '"contactInformation":"","timezone":"UTC"}}}',
              )
            : null,
      );
      await openInventoryDetails(tester, adapter);

      expect(find.text('Edit'), findsNothing);
    });
  });
}
