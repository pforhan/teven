import 'dart:convert';

import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/models/customer.dart';
import 'package:teven_app/routing/app_router.dart';
import 'package:teven_app/widgets/responsive_list_view.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

/// Task 4.14 — the list must not flash to a spinner on every search.
///
/// **Every test that observes the behaviour asserts on a single frame taken
/// while a request is in flight**, because that is the only moment the
/// behaviour exists. That dictates the shape of these tests: none of them may
/// call `pumpAndSettle` while that frame is current, because the thing on screen
/// — a `LinearProgressIndicator` — animates indefinitely and settling would run
/// forever. They `pump()` a fixed duration and look, then **drain afterwards**.
///
/// The drain is teardown hygiene, not part of the assertion, and it is not
/// optional: dio leaves a zero-duration timer pending until a request completes,
/// so a test that ends mid-flight fails with "A Timer is still pending even
/// after the widget tree was disposed" no matter what it asserted.
///
/// Every test here was checked against a build with the retention deleted, and
/// two of the first three passed without it. That is recorded at the bottom of
/// the file rather than left to be rediscovered.
void main() {
  const desktopWidth = 1500.0;
  const tallViewport = 2400.0;
  const viewCustomers = 'VIEW_CUSTOMERS_ORGANIZATION';
  const manageCustomers = 'MANAGE_CUSTOMERS_ORGANIZATION';

  /// A `GET /api/customers` page.
  ///
  /// Offset- and limit-aware, so a fixture claiming `total: 60` actually serves
  /// 25 rows and then 25 more. Returning all 60 in one response labelled
  /// `limit: 25` would be a fixture the real server cannot produce, and the
  /// first version of this file did exactly that — which made the "Showing 25 of
  /// 60" assertions fail for a reason that had nothing to do with the behaviour
  /// under test.
  StubResponse customersPage(List<String> names, int offset, int limit) =>
      StubResponse.json(
        jsonEncode({
          'success': true,
          'data': {
            'items': [
              for (
                var i = offset;
                i < (offset + limit).clamp(0, names.length);
                i++
              )
                {
                  'customerId': i + 1,
                  'name': names[i],
                  'phone': '555-0100',
                  'address': '$i Example Street',
                  'notes': '',
                  'organization': {
                    'organizationId': 1,
                    'name': 'Acme',
                    'contactInformation': '',
                  },
                },
            ],
            'total': names.length,
            'limit': limit,
            'offset': offset,
          },
        }),
      );

  /// The customer endpoints.
  ///
  /// [namesFor] decides the rows each search returns and [failureFor] can
  /// reject one, which is how a test gets a search into a failed state.
  StubAdapter customerAdapter({
    required List<String> Function(String? search) namesFor,
    StubResponse? Function(String? search)? failureFor,
  }) => contextAdapter(
    permissions: const [viewCustomers, manageCustomers],
    forOtherRoutes: (options) {
      if (options.path != '/api/customers' || options.method != 'GET') {
        if (options.method == 'DELETE') return const StubResponse.noContent();
        return null;
      }
      final search = options.queryParameters['search'] as String?;
      final failure = failureFor?.call(search);
      if (failure != null) return failure;
      final offset = (options.queryParameters['offset'] as num?)?.toInt() ?? 0;
      final limit = (options.queryParameters['limit'] as num?)?.toInt() ?? 25;
      return customersPage(namesFor(search), offset, limit);
    },
  );

  /// A 500 for one search term.
  StubResponse unavailable() => const StubResponse.json(
    '{"success":false,"data":{},'
    '"error":{"message":"Customer service unavailable"}}',
    status: 500,
  );

  Future<ProviderContainer> openCustomers(
    WidgetTester tester,
    StubAdapter adapter, {
    double height = tallViewport,
  }) async {
    final container = await pumpApp(
      tester,
      width: desktopWidth,
      height: height,
      token: 'token',
      adapter: adapter,
    );
    await goToAndLoad(tester, container, AppRoutes.customers);
    return container;
  }

  List<RequestOptions> getRequests(StubAdapter adapter) => adapter.requests
      .where((o) => o.path == '/api/customers' && o.method == 'GET')
      .toList();

  /// Types a search and pumps past the 300ms debounce, so the next request is in
  /// flight but has not been answered.
  ///
  /// Returns without settling, because the caller needs to observe the frame in
  /// between.
  Future<void> searchWithoutSettling(WidgetTester tester, String term) async {
    await tester.enterText(find.byType(TextField), term);
    await tester.pump(const Duration(milliseconds: 350));
  }

  group('a search in flight', () {
    testWidgets('leaves the previous rows on screen', (tester) async {
      final adapter = customerAdapter(
        namesFor: (search) => search == null ? ['Alpha', 'Beta'] : ['Alpha'],
      );
      await openCustomers(tester, adapter);
      expect(find.text('Beta'), findsOneWidget);

      await searchWithoutSettling(tester, 'Al');

      // **The whole of task 4.14.** Before the fix the card — heading, column
      // headers and every row — was replaced by a centred spinner, so the list
      // blinked out and back on each debounced keystroke.
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      // And specifically *not* the thing that caused it. This pair of
      // assertions is what makes the test bite: with a plain spinner the rows
      // are absent, and with the rows present there is no spinner. Either half
      // alone is satisfiable by the broken version.
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await settleRequests(tester);
    });

    testWidgets('keeps the column headers and the heading up', (tester) async {
      final adapter = customerAdapter(
        namesFor: (search) => search == null ? ['Alpha', 'Beta'] : ['Alpha'],
      );
      await openCustomers(tester, adapter);

      await searchWithoutSettling(tester, 'Al');

      // The blink was not only the rows: the whole card went, so the header and
      // the column labels went with it. Asserted separately because a fix that
      // kept the rows but still replaced the header would pass the test above.
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Address'), findsOneWidget);
      expect(find.text('Customers'), findsWidgets);

      await settleRequests(tester);
    });

    testWidgets('does not move the list a single pixel', (tester) async {
      final adapter = customerAdapter(
        namesFor: (search) => search == null ? ['Alpha', 'Beta'] : ['Alpha'],
      );
      await openCustomers(tester, adapter);

      // The rect *before* the search, which is what must not change.
      final before = tester.getRect(
        find.byType(ResponsiveListView<CustomerResponse>),
      );

      await searchWithoutSettling(tester, 'Al');

      // **The bug this pins was found by eye in a browser, not by a test.** The
      // first version of the fix put a 2px `LinearProgressIndicator` above the
      // card, which pushed the whole list down by its own height for the duration
      // of every search — a much smaller version of the very flash this task
      // exists to remove. The indicator was moving the thing it was reporting on.
      //
      // So the assertion is geometric rather than "no spinner is present":
      // anything inserted above the card shifts it, whatever it is called. An
      // earlier draft asserted only the absence of a `LinearProgressIndicator`,
      // which a differently-named or differently-sized indicator would pass.
      final during = tester.getRect(
        find.byType(ResponsiveListView<CustomerResponse>),
      );
      // Both of these, and only here: the row count is unchanged while the
      // request is in flight, so any movement is the chrome's doing.
      expect(during.top, before.top);
      expect(during.height, before.height);

      await settleRequests(tester);

      // **Top only after the search lands.** The result has a different number
      // of rows than the retained one — one match instead of two — so the card
      // is genuinely shorter, and asserting equal heights here would be asserting
      // that new data does not change the list. It also caught a wrong version of
      // this test: the first draft checked height after settling and failed
      // because the search really had returned fewer rows.
      final after = tester.getRect(
        find.byType(ResponsiveListView<CustomerResponse>),
      );
      expect(after.top, before.top);
    });

    testWidgets('hides the footer, which would describe the wrong query', (
      tester,
    ) async {
      final adapter = customerAdapter(
        namesFor: (search) => search == null
            ? List.generate(60, (i) => 'Customer $i')
            : ['Alpha'],
      );
      await openCustomers(tester, adapter);
      expect(find.text('Showing 25 of 60'), findsOneWidget);

      await searchWithoutSettling(tester, 'Al');

      // "Showing 25 of 60" is true of the *retained* result and false of the one
      // being fetched, and a "Load more" here would page the previous query.
      expect(find.text('Showing 25 of 60'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Load more'), findsNothing);

      await settleRequests(tester);
    });
  });

  group('when the search resolves', () {
    testWidgets('the new rows replace the old ones', (tester) async {
      final adapter = customerAdapter(
        namesFor: (search) => search == null ? ['Alpha', 'Beta'] : ['Gamma'],
      );
      await openCustomers(tester, adapter);

      await searchWithoutSettling(tester, 'Ga');
      await settleRequests(tester);

      // The retained rows must go, or the list would be a union of two queries.
      expect(find.text('Beta'), findsNothing);
      expect(find.text('Gamma'), findsOneWidget);
    });

    testWidgets('clearing the box goes back to the full list', (tester) async {
      final adapter = customerAdapter(
        namesFor: (search) => search == null ? ['Alpha', 'Beta'] : ['Gamma'],
      );
      await openCustomers(tester, adapter);

      await searchWithoutSettling(tester, 'Ga');
      await settleRequests(tester);
      expect(find.text('Gamma'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 350));
      await settleRequests(tester);

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsNothing);
    });
  });

  group('a search that fails', () {
    testWidgets('shows the error above the previous rows', (tester) async {
      final adapter = customerAdapter(
        namesFor: (search) => search == null ? ['Alpha', 'Beta'] : ['Gamma'],
        failureFor: (search) => search == null ? null : unavailable(),
      );
      await openCustomers(tester, adapter);

      await searchWithoutSettling(tester, 'Ga');
      await settleRequests(tester);

      // **Parity with `TableView.tsx`, where `:40` and `:42` are siblings** —
      // React rendered the error banner and the previous table together. The
      // port replaced the list with the error, which the plan never mentioned
      // and which the same mechanism fixes.
      expect(find.text('Error: Customer service unavailable'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('a failure on the first load still shows only the error', (
      tester,
    ) async {
      // Nothing was ever loaded, so there are no stale rows to put the banner
      // above — and showing the empty-state message instead would claim there
      // is nothing to find rather than that the request failed.
      final adapter = customerAdapter(
        namesFor: (_) => ['Alpha'],
        failureFor: (_) => unavailable(),
      );
      final container = await pumpApp(
        tester,
        width: desktopWidth,
        height: tallViewport,
        token: 'token',
        adapter: adapter,
      );
      await goToAndLoad(tester, container, AppRoutes.customers);

      expect(find.text('Error: Customer service unavailable'), findsOneWidget);
      expect(find.text('No customers found.'), findsNothing);
    });
  });

  group('a sort in flight', () {
    testWidgets('leaves the previous rows up, exactly as a search does', (
      tester,
    ) async {
      final adapter = customerAdapter(namesFor: (_) => ['Alpha', 'Beta']);
      await openCustomers(tester, adapter);

      // Sorting is the same shape of change — a new query key — so it must get
      // the same treatment. Asserting only the search path would leave a fix
      // that special-cased the search box.
      await tester.tap(find.text('Name'));
      await tester.pump();

      expect(find.text('Beta'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await settleRequests(tester);
    });
  });

  group('pagination still works', () {
    testWidgets('Load more reappears once the search settles', (tester) async {
      final adapter = customerAdapter(
        namesFor: (search) => search == null
            ? List.generate(60, (i) => 'Customer $i')
            : List.generate(60, (i) => 'Match $i'),
      );
      await openCustomers(tester, adapter);

      await searchWithoutSettling(tester, 'Mat');
      expect(find.widgetWithText(OutlinedButton, 'Load more'), findsNothing);

      await settleRequests(tester);

      // Suppressing the footer during a refresh must not suppress it forever,
      // or the list would silently become unpageable after a search. The count
      // carries the "filtered" suffix for the reason on
      // `PagedListView.filtered`.
      expect(find.text('Showing 25 of 60 filtered'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Load more'), findsOneWidget);
    });
  });

  group('the count knows it is counting a filtered set', () {
    testWidgets('says "filtered" once a search term is entered', (
      tester,
    ) async {
      final adapter = customerAdapter(
        namesFor: (search) =>
            search == null ? ['Alpha', 'Beta'] : ['Gamma', 'Delta'],
      );
      await openCustomers(tester, adapter);
      expect(find.text('Showing all 2'), findsOneWidget);

      await searchWithoutSettling(tester, 'Ga');
      await settleRequests(tester);

      // **"Showing all 2" is ambiguous once a filter is on: two of what?** The
      // count is what the server matched, not the size of the table, and on a
      // screen listing a large collection "Showing all 2" reads as though the
      // collection holds two rows. Found by eye in a browser.
      expect(find.text('Showing all 2'), findsNothing);
      expect(find.text('Showing all 2 filtered'), findsOneWidget);
    });

    testWidgets('drops the word again when the box is cleared', (tester) async {
      final adapter = customerAdapter(
        namesFor: (search) => search == null ? ['Alpha'] : ['Gamma'],
      );
      await openCustomers(tester, adapter);

      await searchWithoutSettling(tester, 'Ga');
      await settleRequests(tester);
      expect(find.text('Showing all 1 filtered'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 350));
      await settleRequests(tester);

      expect(find.text('Showing all 1'), findsOneWidget);
      expect(find.text('Showing all 1 filtered'), findsNothing);
    });

    testWidgets('marks a partial filtered page too', (tester) async {
      // The "more to come" wording carries the same ambiguity: "25 of 60" does
      // not say whether 60 is the table or the matches, so the suffix applies
      // here as well rather than only on the completed case.
      final adapter = customerAdapter(
        namesFor: (search) => search == null
            ? List.generate(60, (i) => 'Customer $i')
            : List.generate(40, (i) => 'Match $i'),
      );
      await openCustomers(tester, adapter);
      expect(find.text('Showing 25 of 60'), findsOneWidget);

      await searchWithoutSettling(tester, 'Mat');
      await settleRequests(tester);

      expect(find.text('Showing 25 of 40'), findsNothing);
      expect(find.text('Showing 25 of 40 filtered'), findsOneWidget);
    });
  });

  group('a failed search is not retried behind the scenes', () {
    testWidgets('issues exactly one request for the failed term', (
      tester,
    ) async {
      final adapter = customerAdapter(
        namesFor: (search) => search == null ? ['Alpha'] : ['Gamma'],
        failureFor: (search) => search == null ? null : unavailable(),
      );
      await openCustomers(tester, adapter);

      await searchWithoutSettling(tester, 'Ga');
      // Pump well past Riverpod's default backoff, which starts at 400ms.
      await tester.pump(const Duration(seconds: 3));
      await settleRequests(tester);

      // Riverpod 3 retries a failed build with exponential backoff. Left on,
      // that took the list back through loading — reproducing the flash 4.14
      // was filed for, through the error path instead of the loading one — and
      // produced three requests for a 500, which is never going to succeed on a
      // retry. A 401 or a 403 is worse: never transient, so never retryable.
      final forTheTerm = getRequests(adapter)
          .where((r) => r.queryParameters['search'] == 'Ga')
          .toList();
      expect(forTheTerm, hasLength(1));
    });
  });
}

/// **Two of the first three tests here passed with the retention deleted, and
/// that is worth recording rather than leaving to be rediscovered.** The same
/// failure mode as the column-allocation tests earlier in this phase, and in the
/// same shape: a test that looks like coverage and pins nothing.
///
/// What had happened is that the first draft asserted the footer was hidden
/// during a refresh and that rows were retained, as two separate tests. Both
/// passed against the old `PagedListBody`, which showed a plain spinner — because
/// a spinner *also* hides the footer, since it replaces the list wholesale. Each
/// assertion was true of the broken behaviour.
///
/// What separates them is the **combination** in the first test: the old rows
/// present *and* no `CircularProgressIndicator`. Those are mutually exclusive
/// under the old behaviour and only both true with the fix. The footer
/// assertions are kept, because they are the reason the suppression is
/// deliberate rather than incidental — but on their own they prove nothing, and
/// the note is here so nobody later reads them as the regression guard.
