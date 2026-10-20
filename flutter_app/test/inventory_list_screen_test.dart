import 'dart:convert';

import 'package:dio/dio.dart' show RequestOptions;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/models/inventory.dart';
import 'package:teven_app/routing/app_router.dart';
import 'package:teven_app/screens/inventory/inventory_list_screen.dart';
import 'package:teven_app/widgets/responsive_list_view.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

/// The inventory list — task 4.5, the truncated-events case from 4.13, and the
/// inventory half of the delete confirmation in 4.8.
///
/// Structured like `customer_list_screen_test.dart` on purpose: the two screens
/// share `ResponsiveListView` and now `DebouncedSearchField`, so a behaviour
/// pinned in one and not the other is a difference between the screens rather
/// than a fact about the screen.
void main() {
  /// Wide enough for the extended rail (256) *and* a table (1100) beside it.
  const desktopWidth = 1500.0;
  const viewInventory = 'VIEW_INVENTORY_ORGANIZATION';
  const manageInventory = 'MANAGE_INVENTORY_ORGANIZATION';

  /// One item, hand-built rather than generated from the model.
  StubResponse inventoryPage(
    List<String> names, {
    List<int> eventCounts = const [],
  }) => StubResponse.json(
    jsonEncode({
      'success': true,
      'data': {
        'items': [
          for (var i = 0; i < names.length; i++)
            {
              'inventoryId': i + 1,
              'name': names[i],
              'description': 'Description ${i + 1}',
              'quantity': 10 * (i + 1),
              'events': [
                for (
                  var e = 0;
                  e < (eventCounts.isEmpty ? 0 : eventCounts[i]);
                  e++
                )
                  {'eventId': 100 + e, 'title': '', 'quantity': e + 1},
              ],
              'organization': {
                'organizationId': 1,
                'name': 'Acme',
                'contactInformation': '',
              },
            },
        ],
        'total': names.length,
        'limit': 25,
        'offset': 0,
      },
    }),
  );

  StubAdapter inventoryAdapter({
    List<String> names = const ['Chairs', 'Tables'],
    List<int> eventCounts = const [],
    List<String> permissions = const [viewInventory, manageInventory],
    StubResponse? failure,
  }) => contextAdapter(
    permissions: permissions,
    forOtherRoutes: (options) {
      if (options.path == '/api/inventory' && options.method == 'GET') {
        return failure ?? inventoryPage(names, eventCounts: eventCounts);
      }
      if (options.method == 'DELETE') {
        return const StubResponse.noContent();
      }
      return null;
    },
  );

  Future<ProviderContainer> openInventory(
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
    await goTo(tester, container, AppRoutes.inventory);
    return container;
  }

  List<RequestOptions> getRequests(StubAdapter adapter) => adapter.requests
      .where((o) => o.path == '/api/inventory' && o.method == 'GET')
      .toList();

  /// Hovering the first row, which is what reveals its actions in a table.
  Future<void> hoverFirstRow(WidgetTester tester) async {
    final row = find.text('Chairs');
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(row));
    await gesture.moveTo(tester.getCenter(row));
    await tester.pumpAndSettle();
  }

  group('rendering', () {
    testWidgets('shows the items the server returned', (tester) async {
      await openInventory(tester, inventoryAdapter());

      expect(find.byType(InventoryListScreen), findsOneWidget);
      expect(
        find.byType(ResponsiveListView<InventoryItemResponse>),
        findsOneWidget,
      );
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('Chairs'), findsOneWidget);
      expect(find.text('Tables'), findsOneWidget);
      expect(find.text('Description 1'), findsOneWidget);
      // `InventoryList.tsx:92` stringifies the number; it is a `Text` column.
      expect(find.text('10'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
    });

    testWidgets('is no longer a placeholder', (tester) async {
      await openInventory(tester, inventoryAdapter());

      expect(
        find.text('Not ported yet — see FLUTTER-CONVERT.md.'),
        findsNothing,
      );
      // The rail's own nav item is also labelled "Inventory".
      expect(find.text('Inventory'), findsWidgets);
    });

    testWidgets('queries with the original limit, sort and offset', (
      tester,
    ) async {
      final adapter = inventoryAdapter();
      await openInventory(tester, adapter);

      final request = getRequests(adapter).single;
      expect(request.queryParameters['limit'], 25);
      expect(request.queryParameters['offset'], 0);
      expect(request.queryParameters['sortBy'], 'name');
      expect(request.queryParameters['sortOrder'], 'asc');
      expect(request.queryParameters.containsKey('search'), isFalse);
      // `InventoryList.tsx:26-33` passes `selectedOrganization?.organizationId`,
      // which is null for anyone but a super-admin. Asserting the parameter is
      // absent rather than null: `ListQuery.toParams` drops nulls.
      expect(request.queryParameters.containsKey('organizationId'), isFalse);
    });

    testWidgets('scopes to the selected organization when there is one', (
      tester,
    ) async {
      final adapter = inventoryAdapter();
      await openInventory(
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

      expect(getRequests(adapter).last.queryParameters['organizationId'], 7);
    });

    testWidgets(
      'a failure shows the server message',
      (tester) async {
        await openInventory(
          tester,
          inventoryAdapter(
            failure: const StubResponse.json(
              '{"success":false,"data":{},'
              '"error":{"message":"Inventory service unavailable"}}',
              status: 500,
            ),
          ),
        );

        expect(
          find.text('Error: Inventory service unavailable'),
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

  // Task 4.13 — the third case 4.12 was split off and held back, because it
  // needs this screen to exist.
  group('used in events', () {
    testWidgets('an item never used says so', (tester) async {
      await openInventory(
        tester,
        inventoryAdapter(names: const ['Chairs'], eventCounts: const [0]),
      );

      expect(find.text('Never used'), findsOneWidget);
    });

    testWidgets('names every event when there are few enough', (tester) async {
      await openInventory(
        tester,
        inventoryAdapter(names: const ['Chairs'], eventCounts: const [3]),
      );

      expect(find.text('ID: 100 (Qty: 1)'), findsOneWidget);
      expect(find.text('ID: 101 (Qty: 2)'), findsOneWidget);
      expect(find.text('ID: 102 (Qty: 3)'), findsOneWidget);
      expect(find.textContaining('more'), findsNothing);
    });

    testWidgets('truncates past the cap and counts the rest', (tester) async {
      // **The reason this screen cannot be a transcription.**
      // `InventoryDao.getInventoryItems` builds every row through
      // `toInventoryItemResponse`, which selects *all* of `EventInventory` for
      // the item — so the `events` list is unpaginated on the list endpoint as
      // well as on `GET /api/inventory/{id}`. `InventoryList.tsx:97-103`
      // rendered all of them, and a heavily-used item makes a table row tall
      // enough to swallow the screen.
      await openInventory(
        tester,
        inventoryAdapter(names: const ['Chairs'], eventCounts: const [12]),
      );

      expect(find.text('ID: 100 (Qty: 1)'), findsOneWidget);
      expect(find.text('ID: 102 (Qty: 3)'), findsOneWidget);
      // The fourth entry is past `maxEventsShown` and must not be rendered.
      expect(find.text('ID: 103 (Qty: 4)'), findsNothing);
      expect(find.text('+9 more'), findsOneWidget);
    });

    testWidgets('caps per row, not across the whole list', (tester) async {
      await openInventory(
        tester,
        inventoryAdapter(
          names: const ['Chairs', 'Tables'],
          eventCounts: const [6, 5],
        ),
      );

      // Two independent counts, which is the thing a "show the first N overall"
      // reading would get wrong.
      expect(find.text('+3 more'), findsOneWidget);
      expect(find.text('+2 more'), findsOneWidget);
    });
  });

  group('permissions', () {
    testWidgets('a viewer gets no create button and no row actions', (
      tester,
    ) async {
      await openInventory(
        tester,
        inventoryAdapter(permissions: const [viewInventory]),
      );

      expect(find.text('Create Item'), findsNothing);

      await hoverFirstRow(tester);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
      // The data is still there — the gate is on the actions, not the screen.
      expect(find.text('Chairs'), findsOneWidget);
    });

    testWidgets('a manager gets both', (tester) async {
      await openInventory(tester, inventoryAdapter());

      expect(find.text('Create Item'), findsOneWidget);

      await hoverFirstRow(tester);
      // `findsWidgets`: on the VM `kIsWeb` is false, so every row shows its
      // actions rather than hover-revealing them.
      expect(find.byIcon(Icons.edit), findsWidgets);
      expect(find.byIcon(Icons.delete), findsWidgets);
    });
  });

  group('delete', () {
    testWidgets(
      'asks first, naming the record, and cancelling changes nothing',
      (tester) async {
        final adapter = inventoryAdapter();
        await openInventory(tester, adapter);
        await hoverFirstRow(tester);

        await tester.tap(find.byIcon(Icons.delete).first);
        await tester.pumpAndSettle();

        expect(find.text('Delete inventory item'), findsOneWidget);
        // `window.confirm` said "this inventory item"; the shared dialog from
        // task 4.8 names it instead.
        expect(find.textContaining('Chairs'), findsWidgets);

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(adapter.requests.where((o) => o.method == 'DELETE'), isEmpty);
        expect(find.text('Delete inventory item'), findsNothing);
      },
    );

    testWidgets('confirming deletes and refetches', (tester) async {
      final adapter = inventoryAdapter();
      await openInventory(tester, adapter);
      await hoverFirstRow(tester);

      await tester.tap(find.byIcon(Icons.delete).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await settleRequests(tester);

      expect(
        adapter.requests.where((o) => o.method == 'DELETE').map((o) => o.path),
        ['/api/inventory/1'],
      );
      // `InventoryList.tsx:63` re-fetched after deleting.
      expect(getRequests(adapter), hasLength(2));
    });
  });

  group('sorting', () {
    testWidgets('quantity sorts, and a second tap reverses it', (tester) async {
      final adapter = inventoryAdapter();
      await openInventory(tester, adapter);

      expect(getRequests(adapter).map((r) => r.queryParameters['sortBy']), [
        'name',
      ]);

      await tester.tap(find.text('Quantity'));
      await settleRequests(tester);
      expect(getRequests(adapter).map((r) => r.queryParameters['sortBy']), [
        'name',
        'quantity',
      ]);
      // A different column starts ascending rather than inheriting the
      // direction — `InventoryList.tsx:50-57`.
      expect(getRequests(adapter).map((r) => r.queryParameters['sortOrder']), [
        'asc',
        'asc',
      ]);

      await tester.tap(find.text('Quantity'));
      await settleRequests(tester);
      expect(getRequests(adapter).map((r) => r.queryParameters['sortOrder']), [
        'asc',
        'asc',
        'desc',
      ]);
    });

    testWidgets('description and events are not sortable, as in the original', (
      tester,
    ) async {
      final adapter = inventoryAdapter();
      await openInventory(tester, adapter);

      // `InventoryDao` honours `sortBy` for `name` and `quantity` only, and
      // these two columns are not marked sortable in the React original
      // either — so this is the original's choice, not a server limit.
      await tester.tap(find.text('Description'));
      await settleRequests(tester);
      await tester.tap(find.text('Used in Events'));
      await settleRequests(tester);

      expect(getRequests(adapter).map((r) => r.queryParameters['sortBy']), [
        'name',
      ]);
    });
  });

  group('cards at mobile', () {
    testWidgets('a narrow viewport renders cards, not a table', (tester) async {
      await openInventory(
        tester,
        inventoryAdapter(names: const ['Chairs'], eventCounts: const [2]),
        // Phone width. The list sees the content column, which is the whole
        // window here — no rail at this breakpoint.
        width: 500,
      );

      expect(find.byType(Table), findsNothing);
      expect(find.text('Chairs'), findsOneWidget);
      // The card layout labels every column rather than relying on a header,
      // so "Quantity" appears as a field label rather than a column head.
      expect(find.text('Quantity'), findsWidgets);
      expect(find.text('ID: 100 (Qty: 1)'), findsOneWidget);
      // Actions are always visible on a card — there is no hover to reveal
      // them, and hiding them would make them unreachable on a touch device.
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });
  });
}
