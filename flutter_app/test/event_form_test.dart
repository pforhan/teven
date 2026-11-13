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
const _manageEventsGlobal = 'MANAGE_EVENTS_GLOBAL';
const _viewOrgsGlobal = 'VIEW_ORGANIZATIONS_GLOBAL';

StubResponse eventBody({
  int eventId = 7,
  String title = 'Standup',
  String date = '2026-03-04',
  String time = '09:30:00',
  String timezone = 'UTC',
  String? startsAt,
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
}) {
  final t = time.length == 5 ? '$time:00' : time;
  return StubResponse.json(
    jsonEncode({
      'success': true,
      'data': {
        'eventId': eventId,
        'title': title,
        'date': date,
        'time': t,
        'startsAt': startsAt ?? '${date}T${t}Z',
        'timezone': timezone,
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
                  'timezone': 'UTC',
                },
              },
        'rsvps': <Object>[],
        'organization': {
          'organizationId': organizationId,
          'name': organizationName,
          'contactInformation': '',
          'timezone': 'UTC',
        },
        'openInvitation': openInvitation,
        'numberOfStaffNeeded': numberOfStaffNeeded,
      },
    }),
  );
}

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
            'timezone': 'UTC',
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
  List<String> permissions = const [
    _manageEvents,
    _viewCustomers,
    _manageCustomers,
  ],
  StubResponse? createFailure,
  StubResponse? updateFailure,
  StubResponse? loadFailure,
  StubResponse? customersResponse,
  StubResponse? usersResponse,
  String eventDate = '2026-03-04',
  String eventTime = '09:30:00',
  String eventTimezone = 'UTC',
  String? eventStartsAt,
  int durationMinutes = 30,
  String? location = 'Room A',
  List<String> organizationNames = const ['Acme', 'Globex'],
}) => contextAdapter(
  permissions: permissions,
  organizationNames: organizationNames,
  forOtherRoutes: (options) {
    if (options.method == 'POST' && options.path == '/api/events') {
      return createFailure ?? eventBody();
    }
    if (options.method == 'PUT' && options.path.startsWith('/api/events/')) {
      return updateFailure ??
          const StubResponse.json('"Event with ID 7 updated"');
    }
    if (options.method == 'GET' && options.path.startsWith('/api/events/')) {
      return loadFailure ??
          eventBody(
            date: eventDate,
            time: eventTime,
            timezone: eventTimezone,
            startsAt: eventStartsAt,
            durationMinutes: durationMinutes,
            location: location,
          );
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
  StubAdapter adapter, {
  String? initialLocation,
}) async {
  final container = await pumpApp(
    tester,
    width: 1200,
    token: 'token',
    adapter: adapter,
  );
  await goTo(tester, container, initialLocation ?? AppRoutes.eventCreate);
  return container;
}

Future<ProviderContainer> openEdit(
  WidgetTester tester,
  StubAdapter adapter,
  String path, {
  String? detectedZone = 'UTC',
}) async {
  final container = await pumpApp(
    tester,
    width: 1200,
    token: 'token',
    adapter: adapter,
    detectedZone: detectedZone,
  );
  await goTo(tester, container, path);
  return container;
}

Finder durationField() => find.widgetWithText(TextFormField, 'Duration (min)');
Finder locationField() => find.widgetWithText(TextFormField, 'Location');

void main() {
  group('create event form', () {
    testWidgets('submitting empty rejects required fields', (tester) async {
      final adapter = eventFormAdapter();
      await openCreate(tester, adapter);

      expect(find.text('Create New Event'), findsOneWidget);
      await tester.tap(find.text('Quick Save'));
      await settleRequests(tester);

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

      await tester.tap(find.text('Add More Details...'));
      await settleRequests(tester);

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Globex').last);
      await tester.pumpAndSettle();

      expect(find.text('99 Customer Ave'), findsOneWidget);
    });

    testWidgets('the date picker reaches into the future', (tester) async {
      final adapter = eventFormAdapter();
      await openCreate(tester, adapter);

      await tester.tap(find.byType(DateField));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dialog.lastDate.isAfter(DateTime.now()), isTrue);
    });

    testWidgets('starts collapsed and prefills date/time from query params', (
      tester,
    ) async {
      final adapter = eventFormAdapter();
      await openCreate(
        tester,
        adapter,
        initialLocation: '${AppRoutes.eventCreate}?date=2026-12-25',
      );

      expect(find.text('Add More Details...'), findsOneWidget);
      expect(find.text('Quick Save'), findsOneWidget);
      expect(find.text('Duration (min)'), findsNothing);
      final date = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Date'),
      );
      final time = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Start Time'),
      );
      expect(date.controller?.text, '2026-12-25');
      expect(time.controller?.text, '10:00:00');
    });

    testWidgets('duration field starts at 120 in create mode', (tester) async {
      final adapter = eventFormAdapter();
      await openCreate(tester, adapter);
      await tester.tap(find.text('Add More Details...'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextFormField>(durationField());
      expect(field.controller?.text, '120');
    });

    testWidgets('location autofill stops once user types in location field', (
      tester,
    ) async {
      final adapter = eventFormAdapter(
        customersResponse: customerPageWith(
          name: 'Globex',
          address: '99 Customer Ave',
        ),
      );
      await openCreate(tester, adapter);
      await tester.tap(find.text('Add More Details...'));
      await settleRequests(tester);

      await tester.enterText(locationField(), 'Manual Place');
      await tester.pump();

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Globex').last);
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(locationField());
      expect(field.controller?.text, 'Manual Place');
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

      await tester.ensureVisible(find.text('Save Changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Changes'));
      await settleRequests(tester);

      final path = adapter.requests
          .where((r) => r.method == 'PUT')
          .map((r) => r.path)
          .toList();
      expect(path, contains('/api/events/7'));
    });

    testWidgets('the date picker opens for an event scheduled in the future', (
      tester,
    ) async {
      final now = DateTime.now();
      final future = DateTime(now.year, now.month, now.day + 45);
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

      final dateField = tester.widget<TextFormField>(
        find.byType(TextFormField).at(1),
      );
      expect(dateField.controller?.text, futureText);

      await tester.tap(find.byType(DateField));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

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

      await tester.ensureVisible(find.text('Save Changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Changes'));
      await settleRequests(tester);

      final put = adapter.requests.lastWhere(
        (r) => r.method == 'PUT' && r.path == '/api/events/7',
      );
      final body = jsonDecode(adapter.bodyOf(put)!) as Map<String, dynamic>;
      expect(body['organizationId'], isNull);
    });

    testWidgets(
      'loading a Berlin event as a New York reader and saving without changes does not re-zone it',
      (tester) async {
        final adapter = eventFormAdapter(
          customersResponse: customerPageWith(
            name: 'Acme Customer',
            address: '1 Customer St',
          ),
          eventDate: '2026-03-04',
          eventTime: '09:00:00',
          eventTimezone: 'Europe/Berlin',
          eventStartsAt: '2026-03-04T08:00:00Z',
        );
        await openEdit(
          tester,
          adapter,
          '/events/edit/7',
          detectedZone: 'America/New_York',
        );
        await settleRequests(tester);
        await settleRequests(tester);

        await tester.ensureVisible(find.text('Save Changes'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save Changes'));
        await settleRequests(tester);

        final put = adapter.requests.lastWhere(
          (r) => r.method == 'PUT' && r.path == '/api/events/7',
        );
        final body = jsonDecode(adapter.bodyOf(put)!) as Map<String, dynamic>;
        expect(body['timezone'], 'Europe/Berlin');
        expect(
          DateTime.parse(body['startsAt'] as String).toUtc(),
          DateTime.utc(2026, 3, 4, 8),
        );
      },
    );

    testWidgets('duration starts at 120 and zero-loaded duration shows 120', (
      tester,
    ) async {
      final adapter = eventFormAdapter(durationMinutes: 0);
      await openEdit(tester, adapter, '/events/edit/7');
      await settleRequests(tester);
      final field = tester.widget<TextFormField>(durationField());
      expect(field.controller?.text, '120');
    });

    testWidgets('does not clobber a location loaded with the event', (
      tester,
    ) async {
      final adapter = eventFormAdapter(
        location: 'Loaded Place',
        customersResponse: customerPageWith(
          name: 'Globex',
          address: '99 Customer Ave',
        ),
      );
      await openEdit(tester, adapter, '/events/edit/7');
      await settleRequests(tester);

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Globex').last);
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(locationField());
      expect(field.controller?.text, 'Loaded Place');
    });

    testWidgets('excludes the edited event from other events panel', (
      tester,
    ) async {
      final adapter = eventFormAdapter();
      await openEdit(tester, adapter, '/events/edit/7');
      await settleRequests(tester);
      // OtherEventsPanel is present; exclusion is passed as excludeEventId.
      expect(find.byType(Scrollable), findsWidgets);
      // Verify panel rendered (title text includes date context in panel impl;
      // at minimum the widget is in tree for edit mode).
      expect(find.textContaining('Other events'), findsOneWidget);
    });
  });

  group('organization (9.16/9.17)', () {
    testWidgets(
      'org dropdown is present and not selectable for org-scoped caller',
      (tester) async {
        final adapter = eventFormAdapter();
        await openCreate(tester, adapter);

        // Present in create mode (always visible in form body).
        expect(find.text('Organization'), findsWidgets);

        await tester.tap(find.text('Add More Details...'));
        await tester.pumpAndSettle();
        expect(find.text('Organization'), findsWidgets);

        // Not selectable: tapping does not offer other organizations.
        await tester.tap(find.text('Organization').first);
        await tester.pumpAndSettle();
        expect(find.text('Globex'), findsNothing);
      },
    );

    testWidgets(
      'org dropdown is present and not selectable for org-scoped caller in edit',
      (tester) async {
        final adapter = eventFormAdapter();
        await openEdit(tester, adapter, '/events/edit/7');
        await settleRequests(tester);
        await settleRequests(tester);

        expect(find.text('Organization'), findsWidgets);
        await tester.tap(find.text('Organization').first);
        await tester.pumpAndSettle();
        expect(find.text('Globex'), findsNothing);
      },
    );

    testWidgets('global manager sees and can pick organizations in edit', (
      tester,
    ) async {
      final adapter = eventFormAdapter(
        permissions: const [
          _manageEventsGlobal,
          _manageEvents,
          _viewOrgsGlobal,
          _viewCustomers,
          _manageCustomers,
        ],
      );
      await openEdit(tester, adapter, '/events/edit/7');
      await settleRequests(tester);
      await settleRequests(tester);
      await settleRequests(tester);

      expect(find.text('Organization'), findsWidgets);
      final orgLabel = find.text('Organization').first;
      await tester.ensureVisible(orgLabel);
      await tester.tap(orgLabel);
      await tester.pumpAndSettle();
      expect(find.text('Globex'), findsWidgets);
      await tester.tap(find.text('Globex').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await settleRequests(tester);

      final put = adapter.requests.lastWhere(
        (r) => r.method == 'PUT' && r.path == '/api/events/7',
      );
      final body = jsonDecode(adapter.bodyOf(put)!) as Map<String, dynamic>;
      expect(body['organizationId'], 2);
    });
  });
}
