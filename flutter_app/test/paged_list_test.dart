import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/core/api/api_exception.dart';
import 'package:teven_app/core/services/list_query.dart';
import 'package:teven_app/models/common.dart';
import 'package:teven_app/providers/paged_list.dart';

/// A row, so the controller's tests do not need a real DTO.
///
/// [PagedListController] is generic over `T` and knows nothing about any of
/// them, so everything interesting — which offsets get requested, what happens
/// when a page comes back short, what happens when one fails — is testable
/// against a bare string. Using a real `CustomerResponse` here would only add a
/// constructor to get wrong, and would make these unit tests fail for reasons
/// unrelated to what they are about.
///
/// The stubbed-adapter convention from the rest of the suite is a *socket*
/// convention, for testing what goes over the wire. This is one layer below
/// that: `fetchPage` is already an injected seam, so a closure is both simpler
/// and more direct than routing through dio to reach it.
typedef Row = String;

/// Records every query it is asked for, and answers from a fixed corpus.
class FakePages {
  FakePages({this.total = 60, this.failAtOffset, this.reportedTotal});

  /// How many rows exist in total, across every page.
  final int total;

  /// The offset that should raise instead of answering.
  ///
  /// Mutable so the retry test can let the backend recover without building a
  /// second container — the point being that a retry is an ordinary
  /// `loadMore`, not a separate code path.
  int? failAtOffset;

  /// What to put in the envelope's `total`, when it should disagree with
  /// [total].
  ///
  /// Separate because the interesting failure is a server that *does* return rows
  /// and *does* report `total: 0` — a genuine row-holding page described as
  /// empty. That is what `PaginatedResponse`'s `@Default(0)` produces for any
  /// endpoint that omits the field, and it is the case the clamp exists for.
  /// A backend that simply has no rows does not exercise it at all.
  final int? reportedTotal;

  /// Every query received, in order.
  final List<ListQuery> requests = [];

  /// The offsets alone, which is what most assertions want.
  List<int?> get offsets => requests.map((request) => request.offset).toList();

  /// How many rows an answer at [offset] carries.
  ///
  /// A short final page is the case that matters — it is how the controller
  /// learns there is nothing more, since the server's `total` is not something
  /// the client can rely on being present or fresh.
  int rowsAt(int offset) =>
      total - offset < kListPageSize ? total - offset : kListPageSize;

  /// The fetch to hand to a [PagedListController].
  ///
  /// [orderedGate] is how a test keeps a request **in flight**. A `Future` that
  /// completes on its own cannot express "the second page is still on the wire
  /// while the delete happens", and that ordering is the whole subject of the
  /// delete race — with a synchronous fake the `loadMore` always finishes before
  /// anything else runs, the race never occurs, and a test written for it passes
  /// whether or not the code under test can lose.
  Future<PaginatedResponse<Row>> fetch(ListQuery query) async {
    requests.add(query);
    final offset = query.offset ?? 0;
    await orderedGate?.hold();

    if (offset == failAtOffset) {
      throw const ApiRequestException('Could not reach the service');
    }

    return PaginatedResponse<Row>(
      items: [for (var i = offset; i < offset + rowsAt(offset); i++) 'row-$i'],
      total: reportedTotal ?? total,
      limit: kListPageSize,
      offset: offset,
    );
  }

  /// Lets requests be released one at a time, in an order the test chooses.
  ///
  /// See [OrderedGate] for why the delete race needs this rather than simply
  /// being patient.
  OrderedGate? orderedGate;
}

/// Gates requests one at a time, so a test can decide the order they land in.
///
/// A single shared gate cannot express the delete race: releasing both pending
/// requests together lets them resolve in the order they were *issued*, which
/// puts the reload last and lets it win — so the buggy version passes. The race
/// needs the stale page to arrive **after** the reload, which means choosing the
/// order deliberately rather than letting the runtime pick it.
class OrderedGate {
  final List<Completer<void>> _pending = [];

  /// Waits until at least [count] requests are held here.
  ///
  /// Needed because a request is only held once it has actually *reached* the
  /// gate, which is after the caller has run. Without this the test would be
  /// racing its own setup — releasing before the request it means to control has
  /// arrived, and the ordering it was written to produce would not happen.
  Future<void> waitingFor(int count) async {
    while (_pending.length < count) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Lets the oldest held request complete.
  void releaseOldest() {
    final completer = _pending.removeAt(0);
    if (!completer.isCompleted) completer.complete();
  }

  /// Lets the most recently issued held request complete.
  ///
  /// This is the one the delete race needs. The reload is issued *after* the
  /// page that is already in flight, so releasing by age would resolve them in
  /// issue order — reload last, reload wins — and the buggy version passes.
  /// What has to happen is the reverse: the reload lands, and *then* the stale
  /// request it superseded arrives.
  void releaseLast() {
    final completer = _pending.removeLast();
    if (!completer.isCompleted) completer.complete();
  }

  Future<void> hold() async {
    final completer = Completer<void>();
    _pending.add(completer);
    await completer.future;
  }
}

/// The fake the notifier under test reads from.
///
/// A top-level variable rather than a second constructor parameter, because
/// `PagedRows.new` has to be assignable to `PagedRows Function(ListQuery)` for
/// the family declaration to typecheck — the provider takes only its key.
FakePages? pagesUnderTest;

final pagedRowsProvider = AsyncNotifierProvider.autoDispose
    .family<PagedRows, PagedListState<Row>, ListQuery>(PagedRows.new);

class PagedRows extends PagedListController<Row> {
  PagedRows(super.baseQuery);

  @override
  Future<PaginatedResponse<Row>> fetchPage(ListQuery query) =>
      pagesUnderTest!.fetch(query);
}

/// Boots a container whose list reads from [pages].
ProviderContainer containerOver(FakePages pages) {
  pagesUnderTest = pages;
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  /// A query with nothing but a sort on it — the shape a screen builds when the
  /// user has typed nothing and touched no sort header.
  const base = ListQuery(sortBy: 'name');

  group('the first page', () {
    test('requests offset 0 at the shared page size', () async {
      final pages = FakePages();
      final container = containerOver(pages);

      final state = await container.read(pagedRowsProvider(base).future);

      expect(pages.offsets, [0]);
      expect(pages.requests.single.limit, kListPageSize);
      expect(state.items.length, kListPageSize);
    });

    test(
      'adds paging without disturbing the screen\'s own parameters',
      () async {
        final pages = FakePages();
        final container = containerOver(pages);

        await container.read(
          pagedRowsProvider(
            const ListQuery(
              search: 'glob',
              sortBy: 'name',
              sortOrder: SortOrder.desc,
              organizationId: 7,
            ),
          ).future,
        );

        final sent = pages.requests.single;
        // Paging is added on top of what the screen asked for.
        expect(sent.limit, kListPageSize);
        expect(sent.offset, 0);
        expect(sent.search, 'glob');
        expect(sent.sortBy, 'name');
        expect(sent.sortOrder, SortOrder.desc);
        expect(sent.organizationId, 7);
      },
    );
  });

  group('loadMore', () {
    test('appends the next page at the running offset', () async {
      final pages = FakePages();
      final container = containerOver(pages);
      const provider = ListQuery(sortBy: 'name');

      await container.read(pagedRowsProvider(provider).future);
      await container.read(pagedRowsProvider(provider).notifier).loadMore();

      // The offset is the number of rows already held, not a page counter —
      // they differ as soon as a page comes back short.
      expect(pages.offsets, [0, 25]);

      final state = container.read(pagedRowsProvider(provider)).value!;
      expect(state.items.length, 50);
      expect(state.items.first, 'row-0');
      expect(state.items.last, 'row-49');
    });

    test('a short final page means there is no further request', () async {
      final pages = FakePages(total: 30);
      final container = containerOver(pages);
      const provider = ListQuery(sortBy: 'name');

      await container.read(pagedRowsProvider(provider).future);
      await container.read(pagedRowsProvider(provider).notifier).loadMore();

      expect(pages.offsets, [0, 25]);
      expect(
        container.read(pagedRowsProvider(provider)).value!.hasMore,
        isFalse,
      );

      // And nothing more is asked for, however often it is called.
      await container.read(pagedRowsProvider(provider).notifier).loadMore();
      await container.read(pagedRowsProvider(provider).notifier).loadMore();
      expect(pages.offsets, [0, 25]);
    });

    test('a list smaller than one page has nothing to page', () async {
      final pages = FakePages(total: 3);
      final container = containerOver(pages);
      const provider = ListQuery(sortBy: 'name');

      await container.read(pagedRowsProvider(provider).future);
      await container.read(pagedRowsProvider(provider).notifier).loadMore();

      expect(pages.offsets, [0]);
      expect(
        container.read(pagedRowsProvider(provider)).value!.hasMore,
        isFalse,
      );
    });

    test('ignores a call made while one is already in flight', () async {
      final pages = FakePages();
      final container = containerOver(pages);
      const provider = ListQuery(sortBy: 'name');

      await container.read(pagedRowsProvider(provider).future);

      // Deliberately not awaited one at a time: the second call has to land
      // while the first is still in flight, which is exactly what a scroll
      // listener does — it fires on every frame of a fling.
      final first = container
          .read(pagedRowsProvider(provider).notifier)
          .loadMore();
      final second = container
          .read(pagedRowsProvider(provider).notifier)
          .loadMore();
      await Future.wait([first, second]);

      expect(pages.offsets, [
        0,
        25,
      ], reason: 'a repeated scroll notification must not double-fetch');
      expect(
        container.read(pagedRowsProvider(provider)).value!.items.length,
        50,
      );
    });

    test('a failed page leaves the rows already loaded alone', () async {
      final pages = FakePages(failAtOffset: 25);
      final container = containerOver(pages);
      const provider = ListQuery(sortBy: 'name');

      await container.read(pagedRowsProvider(provider).future);
      await container.read(pagedRowsProvider(provider).notifier).loadMore();

      final state = container.read(pagedRowsProvider(provider)).value!;
      // The first page is still on screen. A failure four rows from the bottom
      // is not a reason to take the twenty-five above it away.
      expect(state.items.length, kListPageSize);
      expect(state.items.first, 'row-0');
      expect(state.loadMoreError?.message, 'Could not reach the service');
      // Still not finished — the footer offers a retry rather than claiming
      // this is everything.
      expect(state.hasMore, isTrue);
    });

    test('a failure is not sticky — the next attempt is a normal one', () async {
      final pages = FakePages(failAtOffset: 25);
      final container = containerOver(pages);
      const provider = ListQuery(sortBy: 'name');

      await container.read(pagedRowsProvider(provider).future);
      await container.read(pagedRowsProvider(provider).notifier).loadMore();
      expect(
        container.read(pagedRowsProvider(provider)).value!.loadMoreError,
        isNotNull,
      );

      // The backend recovers, as it would once the server did.
      pages.failAtOffset = null;
      await container.read(pagedRowsProvider(provider).notifier).loadMore();

      final state = container.read(pagedRowsProvider(provider)).value!;
      expect(state.items.length, 50);
      // The stale failure is cleared. A footer that kept showing the old error
      // after a successful page would tell the user the retry did not work.
      expect(state.loadMoreError, isNull);
    });
  });

  group('a delete while a page is in flight', () {
    test('does not let the stale page overwrite the reloaded one', () async {
      // The race this pins: the user scrolls to the bottom, which starts
      // `loadMore`, and *while that request is in flight* deletes a row. The
      // reload lands first; the older request then arrives carrying rows
      // computed from offsets that predate the delete.
      //
      // Without a generation guard the older response wins and the list shows
      // the deleted row again — silently, with no error anywhere, because both
      // requests succeeded. It is the kind of bug that surfaces as "deleting
      // doesn't stick, sometimes".
      final pages = FakePages(total: 60);
      final container = containerOver(pages);
      const provider = ListQuery(sortBy: 'name');

      // **A subscription, and it is load-bearing.** The provider is
      // `autoDispose`, and reading a notifier only keeps it alive for the
      // duration of that call. With nothing listening, it disposes the moment
      // the last `await` finishes, so the final `read` starts a *fresh* build
      // and returns `AsyncLoading` — whose `.value` is null. The other tests get
      // away without this because they read `.future` immediately beforehand,
      // which re-creates and settles the provider in the same expression.
      final subscription = container.listen(
        pagedRowsProvider(provider),
        (_, _) {},
      );
      addTearDown(subscription.close);

      await container.read(pagedRowsProvider(provider).future);

      // Both requests are held, so the test decides which one lands first.
      final gate = OrderedGate();
      pages.orderedGate = gate;

      // Page two starts, and is held at the gate.
      final inFlight = container
          .read(pagedRowsProvider(provider).notifier)
          .loadMore();
      await gate.waitingFor(1);

      // The delete's reload is issued while page two is still outstanding, and
      // is held behind it.
      final reloaded = container
          .read(pagedRowsProvider(provider).notifier)
          .reload();
      await gate.waitingFor(2);

      // **The order is the whole test.** The reload — issued second, against
      // offset 0 — is released *first*, and only then does the stale page two
      // land. Releasing them together would let them resolve in issue order,
      // putting the reload last, and the buggy version would pass.
      gate.releaseLast();
      await gate.waitingFor(1);
      gate.releaseOldest();
      await Future.wait([inFlight, reloaded]);

      final state = container.read(pagedRowsProvider(provider)).value!;
      // Only the reload's own result survives: one page's worth of rows, not
      // the stale page's fifty.
      expect(state.items.length, kListPageSize);
      expect(state.items.first, 'row-0');
    });
  });

  group('a changed query', () {
    test('starts again from offset 0 instead of appending', () async {
      final pages = FakePages();
      final container = containerOver(pages);

      await container.read(pagedRowsProvider(base).future);
      await container.read(pagedRowsProvider(base).notifier).loadMore();

      const resorted = ListQuery(sortBy: 'quantity');
      final state = await container.read(pagedRowsProvider(resorted).future);

      // The whole point of holding the offset inside the notifier rather than
      // in the query key: the new query starts at the beginning, rather than
      // continuing from wherever the old one stopped.
      expect(pages.offsets, [0, 25, 0]);
      expect(state.items.length, kListPageSize);
      expect(state.items.first, 'row-0');
    });

    test('a different search does not inherit the previous pages', () async {
      final pages = FakePages();
      final container = containerOver(pages);

      await container.read(pagedRowsProvider(base).future);
      await container.read(pagedRowsProvider(base).notifier).loadMore();

      const searched = ListQuery(search: 'glob', sortBy: 'name');
      final state = await container.read(pagedRowsProvider(searched).future);

      expect(state.items.length, kListPageSize);
      expect(pages.requests.last.search, 'glob');
      expect(pages.requests.last.offset, 0);
    });
  });

  group('total', () {
    test('is never reported below the number of rows actually held', () async {
      // 25 rows returned, `total: 0` reported. `PaginatedResponse` defaults
      // `total` to 0, so any endpoint that omits the field produces exactly
      // this — rows on screen and a count that says there are none.
      //
      // The footer renders `Showing {items.length} of {total}`, so an unclamped
      // zero gives "Showing 25 of 0", and a `hasMore` derived from
      // `items.length < total` would be false: a list with 25 rows on screen
      // claiming to be complete, with no button to continue from.
      final pages = FakePages(reportedTotal: 0);
      final container = containerOver(pages);
      const provider = ListQuery(sortBy: 'name');

      await container.read(pagedRowsProvider(provider).future);

      final state = container.read(pagedRowsProvider(provider)).value!;
      expect(state.items.length, kListPageSize);
      expect(state.total, state.items.length);
      // Still pageable — exhaustion is decided by the short page, not the count.
      expect(state.hasMore, isTrue);
    });

    test('an empty result really is finished', () async {
      final pages = FakePages(total: 0);
      final container = containerOver(pages);
      const provider = ListQuery(sortBy: 'name');

      await container.read(pagedRowsProvider(provider).future);

      final state = container.read(pagedRowsProvider(provider)).value!;
      expect(state.items, isEmpty);
      expect(state.total, 0);
      expect(state.hasMore, isFalse);
    });
  });
}
