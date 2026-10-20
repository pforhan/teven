import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:teven_app/widgets/other_events_panel.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

/// The "other events on this day" panel — task 7.7.
///
/// Driven on a page of its own rather than through the event details screen,
/// because the panel's contract is its three inputs — a day, an organization
/// and an event to leave out — and the details screen fixes all three. The
/// details screen's own use of it is covered by
/// `event_details_screen_test.dart`.
void main() {
  /// The panel, on a page of its own, with somewhere for a row to go.
  ///
  /// A local router rather than the app's: the panel navigates with
  /// `context.go`, which needs a [GoRouter] in the tree, and the app's router
  /// would put the whole shell — the rail, the drawer, the boot sequence —
  /// between the test and the thing under test.
  Future<void> pumpPanel(
    WidgetTester tester, {
    required StubAdapter adapter,
    String date = '2026-10-24',
    String organizationId = '7',
    String? excludeEventId,
    bool settle = true,
    ValueNotifier<String>? day,
    void Function(int eventId)? onOpen,
  }) async {
    final container = authTestContainer(adapter: adapter, token: 'token');
    final theDay = day ?? ValueNotifier(date);
    addTearDown(theDay.dispose);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: theDay,
              builder: (context, value, _) => OtherEventsPanel(
                date: value,
                organizationId: organizationId,
                excludeEventId: excludeEventId,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/events/:eventId',
          builder: (context, state) {
            onOpen?.call(int.parse(state.pathParameters['eventId']!));
            return const Scaffold(body: Center(child: Text('the event')));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    if (settle) await settleRequests(tester);
  }

  /// Drains in-flight requests **without** settling frames.
  ///
  /// The shared `settleRequests` ends in `pumpAndSettle`, which cannot settle
  /// while an indeterminate spinner is on screen — and the test below holds a
  /// request open on purpose, so the panel's spinner never goes away.
  Future<void> drainRequests(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  /// An event on the wire, hand-built rather than generated from the model.
  Map<String, dynamic> eventJson({
    required int id,
    String title = 'Fence Repair',
    String date = '2026-10-24',
    String time = '10:00',
    int durationMinutes = 60,
    String? location = '123 Main St',
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
      'organizationId': 7,
      'name': 'Acme',
      'contactInformation': '',
    },
    'openInvitation': false,
    'numberOfStaffNeeded': 0,
  };

  /// The panel's endpoint, and nothing else.
  StubAdapter eventsAdapter({
    List<Map<String, dynamic>> events = const [],
    int? total,
    StubResponse? failure,
  }) => StubAdapter((options) {
    if (options.method == 'GET' && options.path == '/api/events') {
      final error = failure;
      if (error != null) return error;
      return StubResponse.json(
        jsonEncode({
          'success': true,
          'data': {
            'items': events,
            'total': total ?? events.length,
            'limit': 25,
            'offset': 0,
          },
        }),
      );
    }
    return const StubResponse.json(
      '{"success":false,"data":{},"error":{"message":"Not found"}}',
      status: 404,
    );
  });

  group('the request', () {
    testWidgets('asks for that day, in that organization', (tester) async {
      final adapter = eventsAdapter(events: [eventJson(id: 1)]);
      await pumpPanel(
        tester,
        adapter: adapter,
        date: '2026-10-24',
        organizationId: '7',
      );

      final request = adapter.requests.firstWhere(
        (o) => o.path == '/api/events',
      );
      expect(request.queryParameters['organizationId'], 7);
      expect(request.queryParameters['startDate'], '2026-10-24');
      expect(request.queryParameters['endDate'], '2026-10-24');
    });

    testWidgets('asks for nothing without a day', (tester) async {
      final adapter = eventsAdapter();
      await pumpPanel(tester, adapter: adapter, date: '');

      expect(adapter.requests.where((o) => o.path == '/api/events'), isEmpty);
      expect(
        find.text('No other events scheduled for this day.'),
        findsOneWidget,
      );
    });

    testWidgets('asks for nothing without an organization', (tester) async {
      final adapter = eventsAdapter();
      await pumpPanel(tester, adapter: adapter, organizationId: '');

      expect(adapter.requests.where((o) => o.path == '/api/events'), isEmpty);
      expect(
        find.text('No other events scheduled for this day.'),
        findsOneWidget,
      );
    });

    testWidgets('asks for nothing when the organization is not a number', (
      tester,
    ) async {
      // **The React original's `parseInt` is laxer than this.** `parseInt("12x")`
      // is 12 and `parseInt("")` is NaN, while `int.tryParse` refuses both.
      // The stricter reading is the one the server would agree with, and no
      // caller passes anything but digits.
      final adapter = eventsAdapter();
      await pumpPanel(tester, adapter: adapter, organizationId: 'not-a-number');

      expect(adapter.requests.where((o) => o.path == '/api/events'), isEmpty);
    });
  });

  group('the list', () {
    testWidgets('lists the day, earliest first', (tester) async {
      await pumpPanel(
        tester,
        adapter: eventsAdapter(
          events: [
            eventJson(id: 2, title: 'Mulch Delivery', time: '13:15'),
            eventJson(id: 1, title: 'Irrigation Check', time: '07:30'),
          ],
        ),
      );

      expect(find.text('Irrigation Check'), findsOneWidget);
      expect(find.text('Mulch Delivery'), findsOneWidget);
      // **The order, not just the presence** — the sort is the whole point of
      // the panel, and a set of assertions cannot see it.
      expect(
        tester.getTopLeft(find.text('Irrigation Check')).dy,
        lessThan(tester.getTopLeft(find.text('Mulch Delivery')).dy),
      );
    });

    testWidgets('shows the duration and the location', (tester) async {
      await pumpPanel(
        tester,
        adapter: eventsAdapter(
          events: [
            eventJson(id: 1, durationMinutes: 45, location: '456 Business Ave'),
          ],
        ),
      );

      expect(find.text('45 min'), findsOneWidget);
      expect(find.text('456 Business Ave'), findsOneWidget);
    });

    testWidgets('marks the duration and the location with icons', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        adapter: eventsAdapter(
          events: [eventJson(id: 1, location: '456 Business Ave')],
        ),
      );

      // **Material icons, because the Bootstrap Icons were never installed.**
      // `<i className="bi bi-clock">` renders as an empty tag in the React
      // app, so there is nothing to match — task 3.11 settles it: Material
      // icons throughout.
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.byIcon(Icons.place), findsOneWidget);
    });

    testWidgets('rules the list between rows', (tester) async {
      await pumpPanel(
        tester,
        adapter: eventsAdapter(
          events: [
            eventJson(id: 1, title: 'First'),
            eventJson(id: 2, title: 'Second'),
            eventJson(id: 3, title: 'Third'),
          ],
        ),
      );

      // **A rule between the rows, and not after the last one.** Every row of
      // the list this replaced carried a bottom border, which draws one
      // between each pair.
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('leaves out the location when there is none', (tester) async {
      await pumpPanel(
        tester,
        adapter: eventsAdapter(events: [eventJson(id: 1, location: null)]),
      );

      expect(find.text('60 min'), findsOneWidget);
      expect(find.text('123 Main St'), findsNothing);
    });

    testWidgets('leaves out the event it is shown beside', (tester) async {
      await pumpPanel(
        tester,
        adapter: eventsAdapter(
          events: [
            eventJson(id: 1, title: 'Fence Repair'),
            eventJson(id: 2, title: 'Gutter Cleaning'),
          ],
        ),
        excludeEventId: '1',
      );

      expect(find.text('Gutter Cleaning'), findsOneWidget);
      expect(find.text('Fence Repair'), findsNothing);
    });

    testWidgets('says the day is empty when it is', (tester) async {
      await pumpPanel(tester, adapter: eventsAdapter());

      expect(
        find.text('No other events scheduled for this day.'),
        findsOneWidget,
      );
    });
  });

  group('when the day changes', () {
    testWidgets('asks again for the new day', (tester) async {
      final day = ValueNotifier('2026-10-24');
      final adapter = eventsAdapter(events: [eventJson(id: 1)]);
      await pumpPanel(tester, adapter: adapter, day: day);

      day.value = '2026-10-25';
      await tester.pump();
      await settleRequests(tester);

      final dates = adapter.requests
          .where((o) => o.path == '/api/events')
          .map((o) => o.queryParameters['startDate'])
          .toList();
      expect(dates, ['2026-10-24', '2026-10-25']);
      expect(find.text('Other events on 2026-10-25'), findsOneWidget);
    });

    testWidgets('a slow answer for the old day does not replace the new one', (
      tester,
    ) async {
      // **The case the panel's request counter exists for.** The first answer
      // is held back until the second has landed and been shown, and then
      // released — which is what a slow request for a day the user has moved
      // on from looks like from the widget's side.
      final day = ValueNotifier('2026-10-24');
      final held = Completer<void>();

      final adapter = StubAdapter((options) async {
        if (options.queryParameters['startDate'] == '2026-10-24') {
          await held.future;
          return StubResponse.json(
            jsonEncode({
              'success': true,
              'data': {
                'items': [eventJson(id: 1, title: 'The old day')],
                'total': 1,
                'limit': 25,
                'offset': 0,
              },
            }),
          );
        }
        return StubResponse.json(
          jsonEncode({
            'success': true,
            'data': {
              'items': [eventJson(id: 2, title: 'The new day')],
              'total': 1,
              'limit': 25,
              'offset': 0,
            },
          }),
        );
      });

      await pumpPanel(tester, adapter: adapter, day: day, settle: false);

      // Move to the new day while the first answer is still held.
      day.value = '2026-10-25';
      await tester.pump();
      await drainRequests(tester);

      expect(find.text('The new day'), findsOneWidget);

      // Now let the slow one land.
      held.complete();
      await drainRequests(tester);
      await tester.pump();

      // **The late answer is for a day the user has left**, so it must not
      // replace what is on screen.
      expect(find.text('The new day'), findsOneWidget);
      expect(find.text('The old day'), findsNothing);
    });
  });

  group('the states', () {
    testWidgets('shows a spinner while it loads', (tester) async {
      await pumpPanel(
        tester,
        adapter: eventsAdapter(events: [eventJson(id: 1)]),
        settle: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // **Let the request land before the test ends.** A widget test fails on
      // a timer still pending when the tree is torn down, and the request is
      // still in flight here by design.
      await settleRequests(tester);
    });

    testWidgets('says what went wrong rather than claiming the day is empty', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        adapter: eventsAdapter(
          failure: const StubResponse.json(
            '{"success":false,"data":{},'
            '"error":{"message":"Something broke"}}',
            status: 500,
          ),
        ),
      );

      // **The React original logs to the console and shows "No other events
      // scheduled for this day."** — a statement about the day that the
      // failure makes untrue. This says what happened instead.
      expect(find.textContaining('Something broke'), findsOneWidget);
      expect(
        find.text('No other events scheduled for this day.'),
        findsNothing,
      );
    });

    testWidgets('counts the events the server did not send', (tester) async {
      await pumpPanel(
        tester,
        adapter: eventsAdapter(events: [eventJson(id: 1)], total: 12),
      );

      expect(find.textContaining('and 11 more on this day'), findsOneWidget);
    });

    testWidgets('does not count the excluded event as one it did not send', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        adapter: eventsAdapter(
          events: [
            eventJson(id: 1),
            eventJson(id: 2, title: 'Gutter Cleaning'),
          ],
          total: 2,
        ),
        excludeEventId: '1',
      );

      // The excluded event is the one the panel is shown beside — the user
      // already knows about it, so it is not one of the ones not shown.
      expect(find.textContaining('more on this day'), findsNothing);
    });
  });

  group('the rows', () {
    testWidgets('a row goes to the event', (tester) async {
      int? opened;
      await pumpPanel(
        tester,
        adapter: eventsAdapter(events: [eventJson(id: 42)]),
        onOpen: (id) => opened = id,
      );

      await tester.tap(find.text('Fence Repair'));
      await tester.pumpAndSettle();

      expect(opened, 42);
    });
  });
}
