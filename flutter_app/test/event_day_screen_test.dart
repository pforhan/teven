import 'dart:convert';

import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/routing/app_router.dart';
import 'package:teven_app/widgets/create_event_button.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

/// The day view — task 7.11.
///
/// Driven through the real router and the real shell, like the calendar's own
/// tests, so what is under test is the screen a selected day opens on: the panel
/// that lists the day, and the create affordance it carries.
void main() {
  const viewEvents = 'VIEW_EVENTS_ORGANIZATION';
  const manageEvents = 'MANAGE_EVENTS_ORGANIZATION';

  /// An event on the wire, hand-built rather than generated from the model — a
  /// change to `EventResponse` should not quietly change what these tests say
  /// about the wire shape.
  Map<String, dynamic> eventJson({
    required int id,
    required String title,
    required String date,
    String time = '09:30:00',
    int durationMinutes = 60,
    String? location,
  }) => {
    'eventId': id,
    'title': title,
    'date': date,
    'time': time,
    'durationMinutes': durationMinutes,
    'location': location,
    'latitude': null,
    'longitude': null,
    'formattedAddress': null,
    'description': null,
    'inventoryItems': <Map<String, dynamic>>[],
    'customer': null,
    'rsvps': <Map<String, dynamic>>[],
    'organization': {
      'organizationId': 1,
      'name': 'Acme',
      'contactInformation': '',
    },
    'openInvitation': false,
    'numberOfStaffNeeded': 0,
  };

  StubResponse eventsPage(List<Map<String, dynamic>> events) =>
      StubResponse.json(
        jsonEncode({
          'success': true,
          'data': {
            'items': events,
            'total': events.length,
            'limit': 1000,
            'offset': 0,
          },
        }),
      );

  StubAdapter calendarAdapter({
    List<Map<String, dynamic>> events = const [],
    List<String> permissions = const [viewEvents, manageEvents],
    StubResponse? failure,
  }) => contextAdapter(
    permissions: permissions,
    eventsResponder: (query) => failure ?? eventsPage(events),
  );

  /// Boots the app and navigates it to the day view for [date].
  Future<ProviderContainer> openDay(
    WidgetTester tester,
    StubAdapter adapter, {
    String date = '2026-10-24',
  }) async {
    final container = await pumpApp(
      tester,
      token: 'token',
      adapter: adapter,
      prefs: const {
        'selectedOrganization':
            '{"organizationId":1,"name":"Acme","contactInformation":""}',
      },
    );
    await goTo(tester, container, '${AppRoutes.eventDay}?date=$date');
    return container;
  }

  List<RequestOptions> getRequests(StubAdapter adapter) => adapter.requests
      .where((o) => o.path == '/api/events' && o.method == 'GET')
      .toList();

  group('the day view', () {
    testWidgets('lists the other events on the day', (tester) async {
      final adapter = calendarAdapter(
        events: [eventJson(id: 42, title: 'Fence Repair', date: '2026-10-24')],
      );
      await openDay(tester, adapter);

      expect(find.text('Other events on 2026-10-24'), findsOneWidget);
      expect(find.text('Fence Repair'), findsOneWidget);
      expect(find.text('09:30:00'), findsOneWidget);

      // The panel asked for that day, in the selected organization.
      final requests = getRequests(adapter);
      expect(requests, isNotEmpty);
      expect(requests.last.queryParameters['startDate'], '2026-10-24');
      expect(requests.last.queryParameters['endDate'], '2026-10-24');
    });

    testWidgets('offers create only with MANAGE_EVENTS_ORGANIZATION', (
      tester,
    ) async {
      final adapter = calendarAdapter(permissions: const [viewEvents]);
      await openDay(tester, adapter);

      // Absent rather than disabled — the create affordance's own rule, carried
      // over rather than re-litigated here.
      expect(find.byType(CreateEventButton), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('offers create, and it carries the day', (tester) async {
      final container = await openDay(tester, calendarAdapter());

      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(
        currentLocation(container),
        '${AppRoutes.eventCreate}?date=2026-10-24',
      );
      await settleRequests(tester);
    });
  });
}
