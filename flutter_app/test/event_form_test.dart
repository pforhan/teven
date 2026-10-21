import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/routing/app_router.dart';
import 'package:teven_app/widgets/picker_fields.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

const _manageEvents = 'MANAGE_EVENTS_ORGANIZATION';
const _viewCustomers = 'VIEW_CUSTOMERS_ORGANIZATION';
const _manageCustomers = 'MANAGE_CUSTOMERS_ORGANIZATION';

StubResponse eventBody({
  int eventId = 7,
  String title = 'Standup',
  String date = '2026-03-04',
  String time = '09:30:00',
  int durationMinutes = 30,
  String? location = 'Room A',
  String? description = 'Daily',
  int? customerId = 1,
  String customerName = 'Acme Customer',
  String customerAddress = '1 Customer St',
  int organizationId = 1,
  String organizationName = 'Acme',
  bool openInvitation = false,
  int numberOfStaffNeeded = 2,
}) => StubResponse.json(
  jsonEncode({
    'success': true,
    'data': {
      'eventId': eventId,
      'title': title,
      'date': date,
      'time': time,
      'durationMinutes': durationMinutes,
      'location': location,
      'description': description,
      'inventoryItems': <Object>[],
      'customer': customerId == null
          ? null
          : {
              'customerId': customerId,
              'name': customerName,
              'phone': '',
              'address': customerAddress,
              'notes': '',
              'organization': {
                'organizationId': organizationId,
                'name': organizationName,
                'contactInformation': '',
              },
            },
      'rsvps': <Object>[],
      'organization': {
        'organizationId': organizationId,
        'name': organizationName,
        'contactInformation': '',
      },
      'openInvitation': openInvitation,
      'numberOfStaffNeeded': numberOfStaffNeeded,
    },
  }),
);

StubResponse emptyCustomerPage() => StubResponse.json(
  jsonEncode({
    'success': true,
    'data': {'items': <Object>[], 'total': 0, 'limit': 1000, 'offset': 0},
  }),
);

StubResponse customerPageWith({
  required String name,
  required String address,
}) => StubResponse.json(
  jsonEncode({
    'success': true,
    'data': {
      'items': [
        {
          'customerId': 1,
          'name': name,
          'phone': '',
          'address': address,
          'notes': '',
          'organization': {
            'organizationId': 1,
            'name': 'Acme',
            'contactInformation': '',
          },
        },
      ],
      'total': 1,
      'limit': 1000,
      'offset': 0,
    },
  }),
);

StubResponse emptyUserPage() => StubResponse.json(
  jsonEncode({
    'success': true,
    'data': {'items': <Object>[], 'total': 0, 'limit': 1000, 'offset': 0},
  }),
);

StubAdapter eventFormAdapter({
  StubResponse? createFailure,
  StubResponse? updateFailure,
  StubResponse? loadFailure,
  StubResponse? customersResponse,
  StubResponse? usersResponse,
  String eventDate = '2026-03-04',
}) => contextAdapter(
  permissions: const [_manageEvents, _viewCustomers, _manageCustomers],
  forOtherRoutes: (options) {
    if (options.method == 'POST' && options.path == '/api/events') {
      return createFailure ?? eventBody();
    }
    if (options.method == 'PUT' && options.path.startsWith('/api/events/')) {
      return updateFailure ??
          const StubResponse.json('"Event with ID 7 updated"');
    }
    if (options.method == 'GET' && options.path.startsWith('/api/events/')) {
      return loadFailure ?? eventBody(date: eventDate);
    }
    if (options.method == 'GET' && options.path == '/api/customers') {
      return customersResponse ?? emptyCustomerPage();
    }
    if (options.method == 'GET' && options.path == '/api/users') {
      return usersResponse ?? emptyUserPage();
    }
    if (options.method == 'GET' && options.path.startsWith('/api/events')) {
      return StubResponse.json(
        jsonEncode({
          'success': true,
          'data': {'items': <Object>[], 'total': 0, 'limit': 10, 'offset': 0},
        }),
      );
    }
    return null;
  },
);

Future<ProviderContainer> openCreate(
  WidgetTester tester,
  StubAdapter adapter,
) async {
  final container = await pumpApp(
    tester,
    width: 1200,
    token: 'token',
    adapter: adapter,
  );
  await goTo(tester, container, AppRoutes.eventCreate);
  return container;
}

Future<ProviderContainer> openEdit(
  WidgetTester tester,
  StubAdapter adapter,
  String path,
) async {
  final container = await pumpApp(
    tester,
    width: 1200,
    token: 'token',
    adapter: adapter,
  );
  await goTo(tester, container, path);
  return container;
}

void main() {
  group('create event form', () {
    testWidgets('submitting empty rejects required fields', (tester) async {
      final adapter = eventFormAdapter();
      await openCreate(tester, adapter);

      expect(find.text('Create New Event'), findsOneWidget);
      await tester.tap(find.text('Quick Save'));
      await settleRequests(tester);

      // title, date, time are required on the quick form.
      expect(find.text('This field is required'), findsWidgets);
    });

    testWidgets('selecting a customer fills the location', (tester) async {
      final adapter = eventFormAdapter(
        customersResponse: customerPageWith(
          name: 'Globex',
          address: '99 Customer Ave',
        ),
      );
      await openCreate(tester, adapter);

      // Reveal the details section.
      await tester.tap(find.text('Add More Details...'));
      await settleRequests(tester);

      // Pick the customer in the dropdown.
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Globex').last);
      await tester.pumpAndSettle();

      // The location controller should now hold the customer address.
      expect(find.text('99 Customer Ave'), findsOneWidget);
    });

    // The bug this form is here for: the date picker stopped at *today*, so
    // an event could not be scheduled for a day that has not arrived yet.
    // A scheduling app that cannot schedule forward is not a scheduling app.
    testWidgets('the date picker reaches into the future', (tester) async {
      final adapter = eventFormAdapter();
      await openCreate(tester, adapter);

      await tester.tap(find.byType(DateField));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Read the dialog's own bound rather than the rendered grid: the
      // claim under test is the *range*, and which day cells happen to be
      // built depends on the viewport.
      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dialog.lastDate.isAfter(DateTime.now()), isTrue);
    });
  });

  group('edit event form', () {
    testWidgets('loads the event and submits', (tester) async {
      final adapter = eventFormAdapter(
        customersResponse: customerPageWith(
          name: 'Acme Customer',
          address: '1 Customer St',
        ),
      );
      await openEdit(tester, adapter, '/events/edit/7');
      await settleRequests(tester);
      await settleRequests(tester);

      final field = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(field.controller?.text, 'Standup');

      await tester.tap(find.text('Save Changes'));
      await settleRequests(tester);

      final path = adapter.requests
          .where((r) => r.method == 'PUT')
          .map((r) => r.path)
          .toList();
      expect(path, contains('/api/events/7'));
    });

    // Editing an event that is **already scheduled in the future**. The
    // event's own date is loaded into the date field, and the picker used
    // to assert that its initial date fell inside its range — which, with
    // the range capped at today, a future event was outside. The picker
    // threw instead of opening, so the date could not be changed at all
    // on exactly the events that most need it changed.
    testWidgets('the date picker opens for an event scheduled in the future', (
      tester,
    ) async {
      final future = DateTime.now().add(const Duration(days: 45));
      final futureText =
          '${future.year}-'
          '${future.month.toString().padLeft(2, '0')}-'
          '${future.day.toString().padLeft(2, '0')}';

      final adapterWithFutureDate = eventFormAdapter(
        customersResponse: customerPageWith(
          name: 'Acme Customer',
          address: '1 Customer St',
        ),
        eventDate: futureText,
      );

      await openEdit(tester, adapterWithFutureDate, '/events/edit/7');
      await settleRequests(tester);

      // The field holds the future date.
      final dateField = tester.widget<TextFormField>(
        find.byType(TextFormField).at(1),
      );
      expect(dateField.controller?.text, futureText);

      // And the picker opens on it rather than throwing.
      await tester.tap(find.byType(DateField));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    // The one test here that asserts on the **request body** rather than the
    // screen, and it is here because the rule is invisible from the call site:
    // the organization is omitted entirely for an org-scoped manager, and the
    // server treats that very differently from the event's own id arriving back
    // (`EventService.kt:83-89`).
    testWidgets('an org-scoped manager sends no organizationId', (
      tester,
    ) async {
      final adapter = eventFormAdapter(
        customersResponse: customerPageWith(
          name: 'Acme Customer',
          address: '1 Customer St',
        ),
      );
      await openEdit(tester, adapter, '/events/edit/7');
      await settleRequests(tester);

      await tester.tap(find.text('Save Changes'));
      await settleRequests(tester);

      final put = adapter.requests.lastWhere(
        (r) => r.method == 'PUT' && r.path == '/api/events/7',
      );
      final body = jsonDecode(adapter.bodyOf(put)!) as Map<String, dynamic>;
      // **Null, not absent.** `json_serializable` emits every field by default,
      // so the key is present with a null value. That is equivalent to the
      // `undefined` React sends, because the server's branch is
      // `updateEventRequest.organizationId != null` (`EventService.kt:86`) —
      // an absent key and an explicit null both leave it null. Asserting
      // `containsKey` would have tested dio's serialization settings rather
      // than the thing the server actually branches on.
      expect(body['organizationId'], isNull);
    });
  });
}
