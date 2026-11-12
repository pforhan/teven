import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:teven_app/routing/app_router.dart';

import '../support/auth_harness.dart';
import '../support/stub_adapter.dart';

/// Golden coverage for the calendar month grid (task 12.5, calendar half).
///
/// Renders a fixed month (June 2025) with deterministic event placement so the
/// grid layout and event bars can be compared visually. The month is chosen far
/// from "today" so the today highlight does not vary by run date.
void main() {
  const viewEvents = 'VIEW_EVENTS_ORGANIZATION';
  const manageEvents = 'MANAGE_EVENTS_ORGANIZATION';

  Map<String, dynamic> eventJson({
    required int id,
    required String title,
    required String date,
    String time = '09:30:00',
  }) {
    final t = time.length == 5 ? '$time:00' : time;
    return {
      'eventId': id,
      'title': title,
      'date': date,
      'time': t,
      'startsAt': '${date}T${t}Z',
      'timezone': 'UTC',
      'durationMinutes': 60,
      'location': null,
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
        'timezone': 'UTC',
      },
      'openInvitation': false,
      'numberOfStaffNeeded': 0,
    };
  }

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

  testWidgets('calendar month grid - June 2025', (tester) async {
    final events = [
      eventJson(id: 1, title: 'Planning', date: '2025-06-02', time: '09:00:00'),
      eventJson(
        id: 2,
        title: 'Site visit',
        date: '2025-06-10',
        time: '13:30:00',
      ),
      eventJson(id: 3, title: 'Review A', date: '2025-06-18', time: '08:00:00'),
      eventJson(id: 4, title: 'Review B', date: '2025-06-18', time: '10:00:00'),
      eventJson(id: 5, title: 'Review C', date: '2025-06-18', time: '12:00:00'),
      eventJson(id: 6, title: 'Review D', date: '2025-06-18', time: '14:00:00'),
      eventJson(id: 7, title: 'Review E', date: '2025-06-18', time: '16:00:00'),
      eventJson(id: 8, title: 'Wrap up', date: '2025-06-25', time: '11:00:00'),
    ];

    final adapter = contextAdapter(
      permissions: const [viewEvents, manageEvents],
      eventsResponder: (_) => eventsPage(events),
    );

    final container = await pumpApp(
      tester,
      token: 'token',
      width: 1200,
      height: 1000,
      adapter: adapter,
    );
    await goTo(tester, container, AppRoutes.events);

    // Move from the current month to June 2025 deterministically.
    final target = DateFormat.yMMMM().format(DateTime(2025, 6));
    for (var i = 0; i < 24 && find.text(target).evaluate().isEmpty; i++) {
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await settleRequests(tester);
    }
    expect(
      find.text(target),
      findsOneWidget,
      reason: 'expected to reach $target',
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../goldens/calendar_month_grid_june_2025.png'),
    );
  });
}
