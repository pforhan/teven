import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/models/event.dart';
import 'package:teven_app/widgets/rsvp_widget.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

/// The pending-RSVP card — task 7.6.
///
/// `RsvpWidget.tsx` was dead code in the React app: written in the same
/// commit that added `GET /api/events/rsvps/requested`, and never imported by
/// anything since. These tests are for the port's version of it, mounted on
/// the calendar.
void main() {
  const viewEvents = 'VIEW_EVENTS_ORGANIZATION';

  Map<String, dynamic> eventJson({
    required int id,
    String title = 'Rooftop Garden Maintenance',
    String date = '2026-10-24',
    String time = '11:00',
  }) => {
    'eventId': id,
    'title': title,
    'date': date,
    'time': time,
    'durationMinutes': 45,
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
    },
    'openInvitation': false,
    'numberOfStaffNeeded': 0,
  };

  StubAdapter rsvpAdapter({
    List<Map<String, dynamic>> requested = const [],
    StubResponse? rsvpFailure,
  }) => contextAdapter(
    permissions: const [viewEvents],
    forOtherRoutes: (options) {
      if (options.method == 'GET' &&
          options.path == '/api/events/rsvps/requested') {
        return StubResponse.json(
          jsonEncode({'success': true, 'data': requested}),
        );
      }
      if (options.method == 'POST' && options.path.endsWith('/rsvp')) {
        return rsvpFailure ??
            const StubResponse.json('{"success":true,"data":"OK"}');
      }
      return null;
    },
  );

  group('the card', () {
    testWidgets('renders nothing when there is nothing pending', (
      tester,
    ) async {
      await pumpApp(tester, token: 'token', adapter: rsvpAdapter());

      expect(find.byType(RsvpWidget), findsOneWidget);
      expect(find.text('You have pending RSVP requests'), findsNothing);
    });

    testWidgets('lists what is waiting, with the date and time', (
      tester,
    ) async {
      await pumpApp(
        tester,
        token: 'token',
        adapter: rsvpAdapter(
          requested: [
            eventJson(id: 61),
            eventJson(id: 62, title: 'Soil delivery', date: '2026-10-27'),
          ],
        ),
      );

      expect(find.text('You have pending RSVP requests'), findsOneWidget);
      expect(find.text('Rooftop Garden Maintenance'), findsOneWidget);
      expect(find.text('Soil delivery'), findsOneWidget);
      expect(find.text('2026-10-24 at 11:00'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Accept'), findsNWidgets(2));
      expect(find.widgetWithText(FilledButton, 'Decline'), findsNWidgets(2));
    });
  });

  group('answering', () {
    testWidgets('Accept posts "available" and drops the row', (tester) async {
      final adapter = rsvpAdapter(requested: [eventJson(id: 61)]);
      await pumpApp(tester, token: 'token', adapter: adapter);

      await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
      await tester.pump();
      await settleRequests(tester);

      final post = adapter.requests.firstWhere(
        (o) => o.method == 'POST' && o.path == '/api/events/61/rsvp',
      );
      // **A free-form string, not an enum** — the server type is `String`
      // with no validation, and the port's `RsvpAvailability` names the
      // values rather than closing the set.
      expect((post.data as RsvpRequest).availability, 'available');
      expect(
        (post.data as RsvpRequest).availability,
        RsvpAvailability.available,
      );
      // The row goes, because the server no longer holds a *request* for it.
      expect(find.text('Rooftop Garden Maintenance'), findsNothing);
    });

    testWidgets('Decline posts "unavailable" and drops the row', (
      tester,
    ) async {
      final adapter = rsvpAdapter(requested: [eventJson(id: 61)]);
      await pumpApp(tester, token: 'token', adapter: adapter);

      await tester.tap(find.widgetWithText(FilledButton, 'Decline'));
      await tester.pump();
      await settleRequests(tester);

      final post = adapter.requests.firstWhere(
        (o) => o.method == 'POST' && o.path == '/api/events/61/rsvp',
      );
      expect(
        (post.data as RsvpRequest).availability,
        RsvpAvailability.unavailable,
      );
      expect(find.text('Rooftop Garden Maintenance'), findsNothing);
    });

    testWidgets('a failed answer keeps the row and says why', (tester) async {
      final adapter = rsvpAdapter(
        requested: [eventJson(id: 61)],
        rsvpFailure: const StubResponse.json(
          '{"success":false,"data":{},"error":{"message":"Event not found"}}',
          status: 404,
        ),
      );
      await pumpApp(tester, token: 'token', adapter: adapter);

      await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
      await tester.pump();
      await settleRequests(tester);

      // **The row survives a failure**, because the request is still
      // outstanding and hiding it would hide the thing to retry.
      expect(find.text('Rooftop Garden Maintenance'), findsOneWidget);
      expect(find.textContaining('Event not found'), findsOneWidget);
    });
  });
}
