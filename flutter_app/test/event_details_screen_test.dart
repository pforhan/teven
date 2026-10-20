import 'dart:convert';

import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/models/event.dart';
import 'package:teven_app/routing/app_router.dart';
import 'package:teven_app/screens/events/event_details_screen.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

/// The event details screen — task 7.6.
///
/// Driven through the real router and the real shell at a pinned width, so
/// what is under test is the screen a user lands on.
void main() {
  /// Wide enough for the extended rail *and* the two-column layout.
  ///
  /// The screen splits into a main column and a sidebar at
  /// `AppBreakpoints.desktop` (1100) of **content** width — and the extended
  /// rail takes 256px of the window — so a 1400px window leaves about 1144.
  /// 1600 leaves room to spare and does not depend on the rail's exact width.
  const desktopWidth = 1600.0;

  const viewEvents = 'VIEW_EVENTS_ORGANIZATION';
  const manageEvents = 'MANAGE_EVENTS_ORGANIZATION';
  const assignToEventsSelf = 'ASSIGN_TO_EVENTS_SELF';

  /// The green and red the availability buttons use.
  const yesFill = Color(0xFF198754);
  const noFill = Color(0xFFDC3545);

  /// An event on the wire, hand-built rather than generated from the model.
  Map<String, dynamic> eventJson({
    int id = 42,
    String title = 'Fall Cleanup',
    String date = '2026-10-19',
    String time = '08:00',
    int durationMinutes = 90,
    String? location = '123 Main St',
    String? description = 'Rake leaves and clean up debris',
    Map<String, dynamic>? customer,
    List<Map<String, dynamic>> inventoryItems = const [],
    List<Map<String, dynamic>> rsvps = const [],
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
    'description': description,
    'inventoryItems': inventoryItems,
    'customer': customer,
    'rsvps': rsvps,
    'organization': {
      'organizationId': 1,
      'name': 'Acme',
      'contactInformation': '',
    },
    'openInvitation': false,
    'numberOfStaffNeeded': 0,
  };

  Map<String, dynamic> customerJson({
    String name = 'Smith Residence',
    String phone = '555-1234',
    String address = '9 Elm Street',
  }) => {
    'customerId': 226,
    'name': name,
    'phone': phone,
    'address': address,
    'latitude': null,
    'longitude': null,
    'formattedAddress': null,
    'notes': 'Large backyard',
    'organization': {
      'organizationId': 1,
      'name': 'Acme',
      'contactInformation': '',
    },
  };

  Map<String, dynamic> rsvpJson({
    required int userId,
    String displayName = 'Alice',
    String email = 'alice@example.com',
    String availability = 'available',
  }) => {
    'userId': userId,
    'displayName': displayName,
    'email': email,
    'availability': availability,
  };

  /// The adapter every test here uses.
  ///
  /// **Three paths have to be answered, and one of them is easy to miss.**
  /// The app's initial location is the calendar, and the calendar now carries
  /// the pending-RSVP card — so `/api/events/rsvps/requested` is requested on
  /// every boot. Left unanswered it falls through to the harness's 401, which
  /// raises `UnauthorizedException`, trips the single-flight 401 redirect and
  /// signs the user out mid-assertion. The symptom is a test that lands on
  /// `/login` with no rail, which reads as a broken shell.
  StubAdapter detailsAdapter({
    Map<String, dynamic>? event,
    List<String> permissions = const [
      viewEvents,
      manageEvents,
      assignToEventsSelf,
    ],
    StubResponse? loadFailure,
    StubResponse? rsvpFailure,
    StubResponse? deleteFailure,
    List<Map<String, dynamic>> requestedRsvps = const [],
  }) => contextAdapter(
    permissions: permissions,
    forOtherRoutes: (options) {
      if (options.method == 'GET' && options.path == '/api/events') {
        // The calendar on boot, and the "other events on this day" panel.
        // Both want this shape.
        return StubResponse.json(
          jsonEncode({
            'success': true,
            'data': {'items': [], 'total': 0, 'limit': 25, 'offset': 0},
          }),
        );
      }
      if (options.method == 'GET' &&
          options.path == '/api/events/rsvps/requested') {
        return StubResponse.json(
          jsonEncode({'success': true, 'data': requestedRsvps}),
        );
      }
      if (options.method == 'GET' &&
          RegExp(r'^/api/events/\d+$').hasMatch(options.path)) {
        return loadFailure ??
            StubResponse.json(
              jsonEncode({'success': true, 'data': event ?? eventJson()}),
            );
      }
      if (options.method == 'POST' && options.path.endsWith('/rsvp')) {
        return rsvpFailure ??
            const StubResponse.json('{"success":true,"data":"OK"}');
      }
      if (options.method == 'DELETE') {
        return deleteFailure ?? const StubResponse.noContent();
      }
      return null;
    },
  );

  /// The `GET /api/events/{id}` requests made so far.
  List<RequestOptions> eventFetches(StubAdapter adapter) => adapter.requests
      .where(
        (o) =>
            o.method == 'GET' && RegExp(r'^/api/events/\d+$').hasMatch(o.path),
      )
      .toList();

  /// The "other events on this day" panel's own query.
  ///
  /// **Distinguished from the calendar's by the date range.** The calendar
  /// asks for a month; the panel asks for the one day the event is on, so
  /// `startDate == endDate`.
  RequestOptions? otherEventsQuery(StubAdapter adapter) =>
      adapter.requests.where((o) {
        return o.method == 'GET' &&
            o.path == '/api/events' &&
            o.queryParameters['startDate'] == '2026-10-19' &&
            o.queryParameters['endDate'] == '2026-10-19';
      }).firstOrNull;

  /// The availability button with [label].
  ///
  /// **`byWidgetPredicate` and not `byType`,** because `OutlinedButton.icon`
  /// builds an `_OutlinedButtonWithIcon` — a subclass — and `find.byType`
  /// compares the runtime type exactly. A `find.byType(OutlinedButton)` for
  /// these two buttons matches **nothing at all**, and the failure reads as
  /// "the button does not exist" rather than "you named the wrong class".
  Finder availabilityButton(String label) => find
      .ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is OutlinedButton),
      )
      .first;

  Future<ProviderContainer> openDetails(
    WidgetTester tester,
    StubAdapter adapter, {
    double width = desktopWidth,
  }) async {
    final container = await pumpApp(
      tester,
      token: 'token',
      width: width,
      adapter: adapter,
    );
    await goTo(tester, container, '/events/42');
    return container;
  }

  group('rendering', () {
    testWidgets('shows the event', (tester) async {
      await openDetails(tester, detailsAdapter());

      expect(find.text('Fall Cleanup'), findsOneWidget);
      expect(find.text('2026-10-19'), findsOneWidget);
      // The raw wire time and the duration, as `EventDetails.tsx:116` renders
      // them.
      expect(find.text('08:00 (90 min)'), findsOneWidget);
      expect(find.text('123 Main St'), findsOneWidget);
      expect(find.text('Rake leaves and clean up debris'), findsOneWidget);
      expect(find.byType(EventDetailsScreen), findsOneWidget);
    });

    testWidgets('shows the customer and the inventory', (tester) async {
      await openDetails(
        tester,
        detailsAdapter(
          event: eventJson(
            customer: customerJson(),
            inventoryItems: [
              {'inventoryId': 1, 'itemName': 'Rake', 'quantity': 3},
              {'inventoryId': 2, 'itemName': 'Gloves', 'quantity': 20},
            ],
          ),
        ),
      );

      expect(find.text('CUSTOMER'), findsOneWidget);
      expect(find.text('Smith Residence'), findsOneWidget);
      expect(find.text('555-1234'), findsOneWidget);
      expect(find.text('9 Elm Street'), findsOneWidget);
      expect(find.text('Inventory Required'), findsOneWidget);
      expect(find.text('Rake'), findsOneWidget);
      expect(find.text('Gloves'), findsOneWidget);
      // The quantity badge — `badge bg-secondary rounded-pill`.
      expect(find.text('3'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
    });

    testWidgets('omits the description when there is none', (tester) async {
      await openDetails(
        tester,
        detailsAdapter(event: eventJson(description: null)),
      );

      expect(find.text('Notes / Description'), findsNothing);
    });

    testWidgets('omits the location when there is none', (tester) async {
      await openDetails(
        tester,
        detailsAdapter(event: eventJson(location: null)),
      );

      expect(find.text('123 Main St'), findsNothing);
    });
  });

  group('the load', () {
    testWidgets('shows the failure rather than spinning forever', (
      tester,
    ) async {
      await openDetails(
        tester,
        detailsAdapter(
          loadFailure: const StubResponse.json(
            '{"success":false,"data":{},"error":{"message":"Event not found"}}',
            status: 404,
          ),
        ),
      );

      // **The divergence from the React original.** `EventDetails.tsx:80`
      // returns a spinner whenever the event is null, and the error it
      // catches is rendered *inside* the card that the spinner replaces — so
      // a failed load spins forever and says nothing. The port shows the
      // message.
      expect(find.textContaining('Event not found'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // And the way back is still there.
      expect(find.text('Back to Events'), findsOneWidget);
    });
  });

  group('permissions', () {
    testWidgets('a manager gets edit and delete', (tester) async {
      await openDetails(tester, detailsAdapter());

      expect(find.widgetWithText(OutlinedButton, 'Edit'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Delete'), findsOneWidget);
    });

    testWidgets('a viewer gets neither', (tester) async {
      await openDetails(
        tester,
        detailsAdapter(permissions: const [viewEvents, assignToEventsSelf]),
      );

      expect(find.widgetWithText(OutlinedButton, 'Edit'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Delete'), findsNothing);
    });

    testWidgets('without ASSIGN_TO_EVENTS_SELF there is no RSVP control', (
      tester,
    ) async {
      await openDetails(
        tester,
        detailsAdapter(permissions: const [viewEvents, manageEvents]),
      );

      // `EventDetails.tsx:187-203`.
      expect(
        find.text("You don't have permission to RSVP to this event."),
        findsOneWidget,
      );
      expect(find.text('Going'), findsNothing);
      expect(find.text('Not Going'), findsNothing);
    });

    testWidgets('with it, there is', (tester) async {
      await openDetails(tester, detailsAdapter());

      expect(find.text('Going'), findsOneWidget);
      expect(find.text('Not Going'), findsOneWidget);
    });
  });

  group('deleting', () {
    testWidgets('asks first, and cancelling changes nothing', (tester) async {
      final adapter = detailsAdapter();
      await openDetails(tester, adapter);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
      await tester.pumpAndSettle();

      // **The shared dialog** — task 4.8's sixth and last `window.confirm`.
      expect(find.text('Delete event'), findsOneWidget);
      expect(find.textContaining('Fall Cleanup'), findsWidgets);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(adapter.requests.where((o) => o.method == 'DELETE'), isEmpty);
    });

    testWidgets('confirming deletes and navigates away', (tester) async {
      final adapter = detailsAdapter();
      final container = await openDetails(tester, adapter);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pump();
      await settleRequests(tester);

      expect(
        adapter.requests.firstWhere(
          (o) => o.method == 'DELETE' && o.path == '/api/events/42',
        ),
        isNotNull,
      );
      // **Away, not a refetch.** `EventDetails.tsx:49` navigates to the events
      // list, and the record is gone — there is nothing to refetch. This is
      // the one delete in the app where *not* refetching is the point.
      expect(currentPath(container), AppRoutes.events);
    });

    testWidgets('a failed delete keeps the screen and says why', (
      tester,
    ) async {
      final adapter = detailsAdapter(
        deleteFailure: const StubResponse.json(
          '{"success":false,"data":{},"error":{"message":"Event not found"}}',
          status: 404,
        ),
      );
      final container = await openDetails(tester, adapter);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pump();
      await settleRequests(tester);

      expect(find.textContaining('Event not found'), findsOneWidget);
      expect(currentPath(container), '/events/42');
    });
  });

  group('RSVP', () {
    testWidgets('"Going" posts "available" and refetches', (tester) async {
      final adapter = detailsAdapter();
      await openDetails(tester, adapter);
      final before = eventFetches(adapter).length;

      await tester.tap(find.text('Going'));
      await tester.pump();
      await settleRequests(tester);

      final post = adapter.requests.firstWhere(
        (o) => o.method == 'POST' && o.path == '/api/events/42/rsvp',
      );
      // `RequestOptions.data` is the typed request — dio has not serialized
      // it by the time the adapter sees it.
      expect((post.data as RsvpRequest).availability, 'available');
      // **The refetch is what repaints the roster**: the server answers
      // `success("OK")`, so nothing comes back to display.
      expect(eventFetches(adapter).length, before + 1);
      expect(find.textContaining('Successfully updated RSVP'), findsOneWidget);
    });

    testWidgets('"Not Going" posts "unavailable"', (tester) async {
      final adapter = detailsAdapter();
      await openDetails(tester, adapter);

      await tester.tap(find.text('Not Going'));
      await tester.pump();
      await settleRequests(tester);

      final post = adapter.requests.firstWhere(
        (o) => o.method == 'POST' && o.path == '/api/events/42/rsvp',
      );
      expect((post.data as RsvpRequest).availability, 'unavailable');
    });

    testWidgets('"Clear my response" posts the original\'s literal string', (
      tester,
    ) async {
      final adapter = detailsAdapter(
        event: eventJson(
          rsvps: [rsvpJson(userId: 1, availability: 'available')],
        ),
      );
      await openDetails(tester, adapter);

      // The clear button only exists once this user has answered something.
      expect(
        find.widgetWithText(TextButton, 'Clear my response'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Clear my response'));
      await tester.pump();
      await settleRequests(tester);

      final post = adapter.requests.firstWhere(
        (o) => o.method == 'POST' && o.path == '/api/events/42/rsvp',
      );
      // `'no response'`, verbatim from `EventDetails.tsx:208`. **Not** `''`,
      // and **not** a member of `RsvpAvailability` — the server stores it as
      // a free-form string, so it is a fourth answer rather than the absence
      // of one.
      expect((post.data as RsvpRequest).availability, 'no response');
      expect(kRsvpCleared, 'no response');
    });

    testWidgets('the answer that is current is the filled button', (
      tester,
    ) async {
      await openDetails(
        tester,
        detailsAdapter(
          event: eventJson(
            rsvps: [
              rsvpJson(
                userId: 99,
                displayName: 'Bob',
                availability: 'unavailable',
              ),
              rsvpJson(
                userId: 1,
                displayName: 'Ada',
                availability: 'available',
              ),
            ],
          ),
        ),
      );

      final going = tester.widget<OutlinedButton>(availabilityButton('Going'));
      final notGoing = tester.widget<OutlinedButton>(
        availabilityButton('Not Going'),
      );

      // Ada's "yes" fills the green button…
      expect(going.style?.backgroundColor?.resolve({}), yesFill);
      // …and Bob's "no" must not fill the red one, which is exactly what
      // taking the first RSVP on the list rather than this user's would do.
      expect(notGoing.style?.backgroundColor?.resolve({}), isNot(noFill));
    });

    testWidgets('there is no clear button when there is nothing to clear', (
      tester,
    ) async {
      await openDetails(tester, detailsAdapter());

      expect(
        find.widgetWithText(TextButton, 'Clear my response'),
        findsNothing,
      );
    });
  });

  group('the roster', () {
    testWidgets('splits the RSVPs three ways', (tester) async {
      await openDetails(
        tester,
        detailsAdapter(
          event: eventJson(
            rsvps: [
              rsvpJson(
                userId: 2,
                displayName: 'Bob',
                availability: 'requested',
              ),
              rsvpJson(
                userId: 3,
                displayName: 'Cleo',
                availability: 'available',
              ),
              rsvpJson(
                userId: 4,
                displayName: 'Dan',
                availability: 'unavailable',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Staff Roster'), findsOneWidget);
      expect(find.text('INVITED'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.text('DECLINED'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Cleo'), findsOneWidget);
      expect(find.text('Dan'), findsOneWidget);
    });

    testWidgets('the declined list is for managers only', (tester) async {
      await openDetails(
        tester,
        detailsAdapter(
          permissions: const [viewEvents, assignToEventsSelf],
          event: eventJson(
            rsvps: [
              rsvpJson(
                userId: 4,
                displayName: 'Dan',
                availability: 'unavailable',
              ),
            ],
          ),
        ),
      );

      // `EventDetails.tsx:256` — the gate is the manage permission, not the
      // size of the list.
      expect(find.text('DECLINED'), findsNothing);
      expect(find.text('Dan'), findsNothing);
    });

    testWidgets('an empty group says so', (tester) async {
      await openDetails(tester, detailsAdapter());

      expect(find.text('No pending invitations.'), findsOneWidget);
      expect(find.text('No one confirmed yet.'), findsOneWidget);
    });

    testWidgets('the badge counts the confirmed', (tester) async {
      await openDetails(
        tester,
        detailsAdapter(
          event: eventJson(
            rsvps: [
              rsvpJson(userId: 3, availability: 'available'),
              rsvpJson(userId: 4, availability: 'available'),
              rsvpJson(userId: 5, availability: 'requested'),
            ],
          ),
        ),
      );

      // `badge bg-primary rounded-pill` next to the heading — the number of
      // people who have confirmed, not the number of people on the roster.
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('the layout', () {
    testWidgets('is one column on a narrow window', (tester) async {
      await openDetails(tester, detailsAdapter(), width: 500);

      // The main card and the sidebar, stacked. The sidebar's "Your
      // Availability" heading is below the event's title.
      final title = tester.getCenter(find.text('Fall Cleanup'));
      final availability = tester.getCenter(find.text('Your Availability'));
      expect(availability.dy, greaterThan(title.dy));
    });

    testWidgets('is two columns on a wide one', (tester) async {
      await openDetails(tester, detailsAdapter(), width: desktopWidth);

      // Side by side: the roster sits to the right of the title.
      final title = tester.getCenter(find.text('Fall Cleanup'));
      final roster = tester.getCenter(find.text('Staff Roster'));
      expect(roster.dx, greaterThan(title.dx));
    });
  });

  group('the other events panel', () {
    testWidgets('asks for this event\'s day and organization', (tester) async {
      final adapter = detailsAdapter();
      await openDetails(tester, adapter);

      // `EventDetails.tsx:175-181` hands the panel the date, the
      // organization and this event's id to leave out.
      final query = otherEventsQuery(adapter);
      expect(query, isNotNull);
      expect(query!.queryParameters['startDate'], '2026-10-19');
      expect(query.queryParameters['endDate'], '2026-10-19');
      expect(query.queryParameters['organizationId'], 1);
    });
  });
}
