import 'dart:convert';

import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/core/util/local_date.dart';
import 'package:teven_app/models/event.dart';
import 'package:teven_app/routing/app_router.dart';
import 'package:teven_app/screens/events/event_list_screen.dart';
import 'package:teven_app/widgets/debounced_search_field.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

/// The event list — task 7.5.
///
/// Driven through the real router and the real shell at a pinned width, so what
/// is under test is the screen a user lands on.
void main() {
  /// Wide enough for the extended rail, a table beside it, *and* six columns.
  ///
  /// 2000 rather than the other list screens' 1500, and the difference is the
  /// column count. `ResponsiveListView` switches to cards on its own available
  /// width, which is the content column after the 256px extended rail — the
  /// Phase 4 log measured that boundary at roughly a 1390px window for a
  /// four-column screen. This screen has six plus an actions column, so 1500
  /// renders *cards*: the sort headers lose their `InkWell` and the rows lose
  /// their `TableRow`, and a test asserting on either fails on a finder rather
  /// than on the behaviour. Tests that are about the card layout pin a width
  /// that produces one rather than assuming the default does.
  const desktopWidth = 2000.0;

  const viewEvents = 'VIEW_EVENTS_ORGANIZATION';
  const manageEvents = 'MANAGE_EVENTS_ORGANIZATION';

  /// An event on the wire, hand-built rather than generated from the model.
  Map<String, dynamic> eventJson({
    required int id,
    required String title,
    required String date,
    String time = '09:30:00',
    String? customerName,
    String? description,
    List<Map<String, dynamic>> rsvps = const [],
  }) => {
    'eventId': id,
    'title': title,
    'date': date,
    'time': time,
    'durationMinutes': 60,
    'location': null,
    'latitude': null,
    'longitude': null,
    'formattedAddress': null,
    'description': description,
    'inventoryItems': <Map<String, dynamic>>[],
    'customer': customerName == null
        ? null
        : {
            'customerId': 5,
            'name': customerName,
            'phone': '',
            'address': '',
            'notes': '',
            'organization': {
              'organizationId': 1,
              'name': 'Acme',
              'contactInformation': '',
            },
          },
    'rsvps': rsvps,
    'organization': {
      'organizationId': 1,
      'name': 'Acme',
      'contactInformation': '',
    },
    'openInvitation': false,
    'numberOfStaffNeeded': 0,
  };

  StubResponse page(
    List<Map<String, dynamic>> events, {
    int total = 0,
    int limit = 25,
    int offset = 0,
  }) => StubResponse.json(
    jsonEncode({
      'success': true,
      'data': {
        'items': events,
        'total': total,
        'limit': limit,
        'offset': offset,
      },
    }),
  );

  StubAdapter eventAdapter({
    List<Map<String, dynamic>> events = const [],
    int total = 0,
    List<String> permissions = const [viewEvents, manageEvents],
    StubResponse? failure,
    StubResponse Function(RequestOptions options)? forMutations,
  }) => contextAdapter(
    permissions: permissions,
    forOtherRoutes: (options) {
      if (options.path == '/api/events' && options.method == 'GET') {
        return failure ?? page(events, total: total);
      }
      // The edit form loads its event on arrival, and `EventService.getEvent`
      // decodes the body as an `EventResponse` — so this cannot fall through to
      // the bare-string answer below, and it must be a *bare* event rather than
      // the paged envelope: decoding `{"items":[…]}` as an event throws inside
      // generated deserialization, which reads as a broken fixture rather than a
      // wrong one.
      if (options.method == 'GET' &&
          RegExp(r'^/api/events/\d+$').hasMatch(options.path)) {
        return StubResponse.json(
          jsonEncode({
            'success': true,
            'data': eventJson(id: 16, title: 'Site visit', date: '2026-10-18'),
          }),
        );
      }
      // Every mutation on this screen — RSVP and delete — goes to
      // `/api/events/{id}/…`, and the server answers a bare-string `success`.
      if (options.path.startsWith('/api/events/')) {
        return forMutations?.call(options) ??
            const StubResponse.json('{"success":true,"data":"OK"}');
      }
      return null;
    },
  );

  Future<ProviderContainer> openList(
    WidgetTester tester,
    StubAdapter adapter, {
    double width = desktopWidth,
    Map<String, Object> prefs = const {},
  }) async {
    final container = await pumpApp(
      tester,
      token: 'token',
      width: width,
      prefs: prefs,
      adapter: adapter,
    );
    await goTo(tester, container, AppRoutes.eventList);
    return container;
  }

  /// The `GET /api/events` requests made so far.
  ///
  /// **Always read `.last`, never `.single`.** The router's `initialLocation` is
  /// `/events` (`app_router.dart:142`), so booting the app renders the calendar
  /// and queries it *before* this navigates to `/events/list`. Both screens hit
  /// the same endpoint, so the list here is calendar-then-list and a `.single`
  /// fails on the count rather than on the parameters under test.
  List<RequestOptions> getRequests(StubAdapter adapter) => adapter.requests
      .where((o) => o.path == '/api/events' && o.method == 'GET')
      .toList();

  /// The table containing the row holding [title].
  ///
  /// Scoping by row rather than asserting globally, because the screen shows
  /// today's date twice — in the start-date filter and in the Date column — and
  /// `findsOneWidget` on either is an assertion about the filter, not the row.
  ///
  /// **`Table`, not `TableRow`.** `ResponsiveListView` builds its rows as
  /// `TableRow`s, but `Table` inflates those into `_TableRow` render objects
  /// that never appear as widgets in the element tree — so
  /// `find.byType(TableRow)` matches nothing at all, and the failure reads as
  /// "the row does not exist" rather than "you named the wrong class". The
  /// `Table` is the nearest ancestor that is findable, and there is exactly one
  /// per list, so `find.descendant` over it scopes to this list and no other.
  Finder rowFor(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(Table));

  /// The RSVP buttons in the row whose title cell is [title].
  ///
  /// Found through the title's row rather than by index, so a test keeps
  /// working when a second row is added and does not silently start asserting
  /// about a different event. `TableRow` is the row `ResponsiveListView` builds
  /// for a table row — a card row has no row to scope to, which is why these
  /// tests pin the desktop width.
  Finder rsvpButtonFor(String title, IconData icon) => find
      .descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(Table)),
        matching: find.byWidgetPredicate(
          (w) =>
              w is IconButton &&
              w.icon is Icon &&
              (w.icon as Icon).icon == icon,
        ),
      )
      .first;

  /// Opens the start-date [DateField]'s picker and chooses [target].
  ///
  /// Driven through the real Material picker rather than by writing the
  /// controller, because the thing under test is that a *picked* date reaches the
  /// query — setting the text directly would pass on a screen whose `onChanged`
  /// was never wired.
  Future<void> pickStartDate(WidgetTester tester, DateTime target) async {
    await tester.tap(find.byType(TextFormField).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('${target.day}').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'OK'));
    await tester.pumpAndSettle();
    await settleRequests(tester);
  }

  /// Reveals the first row's actions.
  ///
  /// **Needed on web and harmless on the VM, which is why it is unconditional.**
  /// `ResponsiveListView` reveals row actions on hover where `kIsWeb`, and always
  /// in a card — so on Chrome the buttons genuinely do not exist until the row is
  /// hovered, and a test that reaches for `find.byTooltip('Delete')` without this
  /// passes on the VM and fails on the web. `customer_list_screen_test.dart`
  /// discovered the same thing; the VM-only pass would have been a green light
  /// for a test that never runs in the browser the app ships to.
  ///
  /// The size gate matters too: the hover reveal exists in the **table** layout
  /// only, which is why [desktopWidth] is what it is.
  Future<void> hoverFirstRow(WidgetTester tester, String title) async {
    final row = find.text(title);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(row));
    await gesture.moveTo(tester.getCenter(row));
    await tester.pumpAndSettle();
  }

  group('rendering', () {
    testWidgets('shows the events the server returned', (tester) async {
      final today = formatLocalDate(DateTime.now());
      await openList(
        tester,
        eventAdapter(
          events: [
            eventJson(
              id: 1,
              title: 'Hedge trimming',
              date: today,
              customerName: 'Globex',
              description: 'Front garden',
            ),
          ],
        ),
      );

      expect(find.text('Hedge trimming'), findsOneWidget);
      // Scoped to the row: the start-date filter holds today's date too, so a
      // global `findsOneWidget` on either would be asserting about the filter.
      expect(
        find.descendant(
          of: rowFor('Hedge trimming'),
          matching: find.text(today),
        ),
        findsOneWidget,
      );
      // The raw wire time, as `EventListPage.tsx:127` renders it.
      expect(
        find.descendant(
          of: rowFor('Hedge trimming'),
          matching: find.text('09:30:00'),
        ),
        findsOneWidget,
      );
      expect(find.text('Front garden'), findsOneWidget);
      expect(find.text('Globex'), findsOneWidget);
    });

    testWidgets('says N/A for an event with no customer', (tester) async {
      final today = formatLocalDate(DateTime.now());
      await openList(
        tester,
        eventAdapter(
          events: [eventJson(id: 2, title: 'No customer', date: today)],
        ),
      );

      // `EventListPage.tsx:128` — `event.customer?.name || 'N/A'`. Not
      // decoration: `customerId` is nullable on the DTO and the schema, so an
      // event with no customer is a real state rather than a broken row.
      expect(find.text('N/A'), findsOneWidget);
    });

    testWidgets('is no longer a placeholder', (tester) async {
      await openList(tester, eventAdapter());

      expect(
        find.text('Not ported yet — see FLUTTER-CONVERT.md.'),
        findsNothing,
      );
      expect(find.byType(EventListScreen), findsOneWidget);
    });
  });

  group('querying', () {
    testWidgets('sends the original sort and the shared page size', (
      tester,
    ) async {
      final adapter = eventAdapter();
      await openList(tester, adapter);

      final request = getRequests(adapter).last;
      expect(request.queryParameters['limit'], 25);
      expect(request.queryParameters['offset'], 0);
      // `sortBy` defaults to `'date'` in the original even though the column it
      // would apply to is the title. **It does nothing** — `EventDao` never reads
      // it (task 10.11) — and it is sent anyway, on the same terms as the three
      // customer headers the server ignores: hiding a control the original shows
      // is a worse divergence than leaving it inert. See task 4.11.
      expect(request.queryParameters['sortBy'], 'date');
      expect(request.queryParameters['sortOrder'], 'asc');
    });

    testWidgets('floors the list at today, with no upper bound', (
      tester,
    ) async {
      final adapter = eventAdapter();
      await openList(tester, adapter);

      final request = getRequests(adapter).last;
      // `EventListPage.tsx:36-44` passes `startDate` and leaves `endDate`
      // undefined. A month *window*, as the calendar sends, would be a
      // different screen.
      expect(
        request.queryParameters['startDate'],
        formatLocalDate(DateTime.now()),
      );
      expect(request.queryParameters.containsKey('endDate'), isFalse);
    });

    testWidgets('picking a start date re-queries with it', (tester) async {
      final adapter = eventAdapter();
      await openList(tester, adapter);
      final before = getRequests(adapter).length;

      // Task 5.9's `DateField`, not a text field: a `type="date"` input the user
      // types into is a `TextFormField` they tap into a picker. Going through the
      // picker is also the only way to reach the integration at all, since the
      // value goes straight into the query and has to be a valid `yyyy-MM-dd`.
      await pickStartDate(tester, DateTime.now().add(const Duration(days: 1)));

      final requests = getRequests(adapter);
      expect(requests.length, before + 1);
      // And it resets the page, which `EventListPage.tsx:210` does explicitly
      // with `setOffset(0)`. That is free here — a changed `ListQuery` is a new
      // provider, which starts at offset 0 — so this pins the outcome rather than
      // the mechanism.
      expect(requests.last.queryParameters['offset'], 0);
      expect(
        requests.last.queryParameters['startDate'],
        formatLocalDate(DateTime.now().add(const Duration(days: 1))),
      );
    });

    testWidgets('"Today" puts the floor back', (tester) async {
      final adapter = eventAdapter();
      await openList(tester, adapter);

      // Move the floor off today first, or "Today" is a no-op — the value it
      // writes is the one already in state, so the `ListQuery` is unchanged, the
      // provider is unchanged and **nothing refetches**. That is also what React
      // does: `useCallback`'s dependency list holds the same string. Worth
      // knowing before writing a test that asserts a request happened.
      await pickStartDate(tester, DateTime.now().add(const Duration(days: 1)));
      final before = getRequests(adapter).length;

      await tester.tap(find.widgetWithText(OutlinedButton, 'Today'));
      await tester.pumpAndSettle();
      await settleRequests(tester);

      final requests = getRequests(adapter);
      expect(requests.length, before + 1);
      expect(
        requests.last.queryParameters['startDate'],
        formatLocalDate(DateTime.now()),
      );
      // The field goes with it, or the control would keep showing a date the
      // list is no longer filtering by — the failure two copies of one value make
      // possible, and the reason both are written from the same place.
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller
            ?.text,
        formatLocalDate(DateTime.now()),
      );
    });

    testWidgets('re-queries when the sort column changes', (tester) async {
      // One row, not zero: `ResponsiveListView` renders no column headers at all
      // for an empty list — the empty message replaces the table — so a test
      // that reaches for the sort header on an empty screen is asserting about
      // a control that was never built.
      final adapter = eventAdapter(
        events: [
          eventJson(
            id: 1,
            title: 'Hedge trimming',
            date: formatLocalDate(DateTime.now()),
          ),
        ],
      );
      await openList(tester, adapter);

      await tester.tap(find.widgetWithText(InkWell, 'Title'));
      await tester.pumpAndSettle();
      await settleRequests(tester);

      // `handleSort` on a new column starts ascending, `EventListPage.tsx:94-102`.
      expect(getRequests(adapter).last.queryParameters['sortBy'], 'title');
      expect(getRequests(adapter).last.queryParameters['sortOrder'], 'asc');
    });
  });

  group('RSVP', () {
    testWidgets('the yes button posts "available" and refetches', (
      tester,
    ) async {
      final today = formatLocalDate(DateTime.now());
      final adapter = eventAdapter(
        events: [eventJson(id: 3, title: 'Site visit', date: today)],
      );
      await openList(tester, adapter);
      // Relative, not absolute: booting the app renders the calendar and queries
      // it before this navigates to the list, so the count on arrival is already
      // two.
      final before = getRequests(adapter).length;

      await tester.tap(rsvpButtonFor('Site visit', Icons.check));
      await tester.pump();
      await settleRequests(tester);

      final post = adapter.requests.firstWhere(
        (o) => o.method == 'POST' && o.path == '/api/events/3/rsvp',
      );
      // `RequestOptions.data` is the typed request, not a JSON string — dio has
      // not serialized it by the time the adapter sees it, because the adapter
      // sits *under* the transformer. Asserting on the string would fail on a
      // correct request for a reason that has nothing to do with availability.
      expect((post.data as RsvpRequest).availability, 'available');
      // `handleRsvp` calls `fetchEvents()`. The server answers `success("OK")`,
      // so the refetch is the only thing that repaints the button.
      expect(getRequests(adapter).length, before + 1);
    });

    testWidgets('the no button posts "unavailable"', (tester) async {
      final today = formatLocalDate(DateTime.now());
      final adapter = eventAdapter(
        events: [eventJson(id: 4, title: 'Site visit', date: today)],
      );
      await openList(tester, adapter);

      await tester.tap(rsvpButtonFor('Site visit', Icons.close));
      await tester.pump();
      await settleRequests(tester);

      expect(
        (adapter.requests
                    .firstWhere(
                      (o) =>
                          o.method == 'POST' && o.path == '/api/events/4/rsvp',
                    )
                    .data
                as RsvpRequest)
            .availability,
        'unavailable',
      );
    });

    testWidgets('the clear button posts the original\'s literal string', (
      tester,
    ) async {
      final today = formatLocalDate(DateTime.now());
      final adapter = eventAdapter(
        events: [eventJson(id: 5, title: 'Site visit', date: today)],
      );
      await openList(tester, adapter);

      await tester.tap(rsvpButtonFor('Site visit', Icons.undo));
      await tester.pump();
      await settleRequests(tester);

      // `'no response'`, verbatim from `EventListPage.tsx:153` — **not** `''`
      // and **not** a member of [RsvpAvailability]. The server stores it as a
      // free-form string, so "improving" it here would change what lands in the
      // `rsvps.availability` column and every existing filter over it. Task
      // 10.17 owns that question.
      expect(
        (adapter.requests
                    .firstWhere(
                      (o) =>
                          o.method == 'POST' && o.path == '/api/events/5/rsvp',
                    )
                    .data
                as RsvpRequest)
            .availability,
        'no response',
      );
      expect(kRsvpCleared, 'no response');
    });

    testWidgets("the current answer is read from this user's own RSVP", (
      tester,
    ) async {
      final today = formatLocalDate(DateTime.now());
      // Two RSVPs, only one of them this user's — `userId: 1` in the harness's
      // context. `EventListPage.tsx:131` finds the current user's among the
      // event's; taking the first would show Bob's answer as yours.
      await openList(
        tester,
        eventAdapter(
          events: [
            eventJson(
              id: 6,
              title: 'Site visit',
              date: today,
              rsvps: [
                {
                  'userId': 99,
                  'displayName': 'Bob',
                  'email': '',
                  'availability': 'unavailable',
                },
                {
                  'userId': 1,
                  'displayName': 'Ada',
                  'email': '',
                  'availability': 'available',
                },
              ],
            ),
          ],
        ),
      );

      final yes = tester.widget<IconButton>(
        rsvpButtonFor('Site visit', Icons.check),
      );
      final no = tester.widget<IconButton>(
        rsvpButtonFor('Site visit', Icons.close),
      );
      // Ada's "yes" lights the green button…
      expect(yes.style?.backgroundColor?.resolve({}), _yesFill);
      // …and Bob's "no" must not light the red one, which is exactly what
      // taking the first RSVP on the list rather than this user's would do.
      expect(no.style?.backgroundColor?.resolve({}), isNot(_noFill));
    });
  });

  group('row actions', () {
    testWidgets('a manager gets edit and delete', (tester) async {
      final today = formatLocalDate(DateTime.now());
      await openList(
        tester,
        eventAdapter(
          events: [eventJson(id: 12, title: 'Site visit', date: today)],
        ),
      );

      await hoverFirstRow(tester, 'Site visit');
      expect(find.byTooltip('Delete'), findsOneWidget);
      expect(find.byTooltip('Edit'), findsOneWidget);
    });

    testWidgets('a viewer gets neither', (tester) async {
      final today = formatLocalDate(DateTime.now());
      await openList(
        tester,
        eventAdapter(
          events: [eventJson(id: 13, title: 'Site visit', date: today)],
          permissions: const [viewEvents],
        ),
      );

      // No hover first: a viewer has no actions to reveal, so revealing them
      // would be the bug rather than the setup.
      expect(find.byTooltip('Delete'), findsNothing);
      expect(find.byTooltip('Edit'), findsNothing);
    });

    testWidgets('delete asks first, and cancelling changes nothing', (
      tester,
    ) async {
      final today = formatLocalDate(DateTime.now());
      final adapter = eventAdapter(
        events: [eventJson(id: 14, title: 'Site visit', date: today)],
      );
      await openList(tester, adapter);

      await hoverFirstRow(tester, 'Site visit');
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();

      // The shared dialog — `EventListPage.tsx:64`, task 4.8's sixth and last
      // call site. Named after the record, because that is what the other five
      // sites do and a generic "Are you sure?" is what made six of them worth
      // sharing.
      expect(find.text('Delete event'), findsOneWidget);
      expect(find.textContaining('Site visit'), findsWidgets);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(adapter.requests.where((o) => o.method == 'DELETE'), isEmpty);
    });

    testWidgets('confirming deletes and reloads from the first page', (
      tester,
    ) async {
      final today = formatLocalDate(DateTime.now());
      final adapter = eventAdapter(
        events: [eventJson(id: 15, title: 'Site visit', date: today)],
      );
      await openList(tester, adapter);
      final before = getRequests(adapter).length;

      await hoverFirstRow(tester, 'Site visit');
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pump();
      await settleRequests(tester);

      expect(
        adapter.requests.firstWhere(
          (o) => o.method == 'DELETE' && o.path == '/api/events/15',
        ),
        isNotNull,
      );
      // `fetchEvents()` in the original — which reset to page zero, because a
      // deleted row shifts every row after it up. A `reload` rather than an
      // invalidation, for the same reason: see `PagedListController.reload`.
      final requests = getRequests(adapter);
      expect(requests.length, before + 1);
      expect(requests.last.queryParameters['offset'], 0);
    });

    testWidgets('edit goes to the edit form', (tester) async {
      final today = formatLocalDate(DateTime.now());
      final container = await openList(
        tester,
        eventAdapter(
          events: [eventJson(id: 16, title: 'Site visit', date: today)],
        ),
      );

      await hoverFirstRow(tester, 'Site visit');
      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      // Read after one pump, not after settling. The edit form loads customers,
      // users and inventory on arrival and the harness 401s an unanswered path,
      // which signs the user out — the same constraint the calendar's navigation
      // tests hit, and for the same reason. The question here is only *where the
      // row action goes*.
      expect(currentPath(container), '/events/edit/16');
      await settleRequests(tester);
    });
  });

  group('the view switch', () {
    testWidgets('goes back to the calendar', (tester) async {
      final container = await openList(tester, eventAdapter());

      await tester.tap(find.widgetWithText(OutlinedButton, 'Calendar view'));
      await tester.pump();
      expect(currentPath(container), AppRoutes.events);
      await settleRequests(tester);
    });

    testWidgets('sits beside the search box, and the date filter below', (
      tester,
    ) async {
      await openList(tester, eventAdapter());

      // **The layout, not the presence.** A test that only checked the button
      // existed would pass on any arrangement — including the one this change
      // was made to replace, where the date field and the search box shared a
      // row and there was no view switch at all. What is being pinned is the
      // *relationship* between three controls, so the assertion is a
      // relationship too.
      //
      // Comparing the centres' `dy` is a relative measurement rather than an
      // absolute one, which is what keeps it out of the trap the Phase 4 log
      // records: a pixel threshold in a widget test measures the test font, not
      // the layout. A `Wrap` centres its children on the cross axis, so two
      // controls in the same row have *identical* centres, and a control in the
      // next row is strictly below.
      final search = tester.getCenter(find.byType(DebouncedSearchField));
      final calendarView = tester.getCenter(
        find.widgetWithText(OutlinedButton, 'Calendar view'),
      );
      final startDate = tester.getCenter(find.byType(TextFormField).first);

      // Same row.
      expect(calendarView.dy, closeTo(search.dy, 1));
      // And the date filter is on a row of its own, below both.
      expect(startDate.dy, greaterThan(search.dy));
    });
  });

  group('create', () {
    testWidgets('is absent without the permission', (tester) async {
      await openList(tester, eventAdapter(permissions: const [viewEvents]));

      expect(find.widgetWithText(FilledButton, 'Create Event'), findsNothing);
    });

    testWidgets('is present with it', (tester) async {
      await openList(tester, eventAdapter());

      expect(find.widgetWithText(FilledButton, 'Create Event'), findsOneWidget);
    });
  });

  group('a failure', () {
    testWidgets('shows the server message and keeps the screen', (
      tester,
    ) async {
      await openList(
        tester,
        eventAdapter(
          failure: const StubResponse.json(
            '{"success":false,"data":{},"error":{"message":"No events for you"}}',
            status: 403,
          ),
        ),
      );

      // `ErrorDisplay` prefixes with "Error: ", so this matches the message
      // rather than the exact widget — the server's wording is the part under
      // test and the prefix belongs to the shared widget.
      expect(find.textContaining('No events for you'), findsOneWidget);
      // And the screen itself is still there, rather than replaced by the banner.
      expect(find.byType(EventListScreen), findsOneWidget);
    });
  });
}

/// The green and red selected fills, from `_RsvpCell`.
///
/// Named here because the assertion is about *which* button is lit. Comparing
/// two colours both computed the same way would pass on both being lit, which is
/// the failure the two-RSVPs fixture is built to catch.
const Color _yesFill = Color(0xFF198754);
const Color _noFill = Color(0xFFDC3545);
