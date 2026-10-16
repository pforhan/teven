import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_exception.dart';
import '../core/services/list_query.dart';
import '../models/common.dart';

/// Turns off Riverpod's automatic retry of a failed provider build.
///
/// **Every list provider passes this, and it is a decision rather than a
/// default.** Riverpod 3 retries a failed build with exponential backoff. For a
/// list screen that is wrong in three separate ways, and only the first is
/// obvious:
///
/// - **It fights task 4.14.** A retry takes the list back through
///   [AsyncLoading], so a single failed search would render the error banner,
///   then the rows, then the banner again as each attempt landed. The flash the
///   user complained about would come back through the error path instead of the
///   loading one.
/// - **It cannot help with the failures that actually occur.** A 401 means the
///   session is gone and `ApiClient`'s unauthorized redirect has already fired;
///   a 403 means the caller lacks the permission and will keep lacking it; a
///   validation error will keep failing. None of those are transient, and
///   retrying each of them twice more is three wasted requests per failure.
/// - **It hides its own work.** An automatic retry that succeeds replaces the
///   error with rows and says nothing, so the screen briefly claims a result the
///   user never asked for and cannot explain.
///
/// What replaces it is the affordance the UI already has: a failed *further
/// page* shows "Try again" in the footer, and a failed *query* shows the
/// server's message. Both are deliberate and both are visible. A silent retry is
/// neither.
///
/// This also has a testing consequence worth recording, because it is how the
/// behaviour was found. Riverpod arms a `Timer` for the retry; the widget-test
/// fake clock does not advance far enough to fire it, so teardown failed with
/// "A Timer is still pending even after the widget tree was disposed" on every
/// test that rendered an error. Those four tests were failing for a reason that
/// had nothing to do with what they assert.
///
/// Typed as `Duration? Function(int, Object)` rather than Riverpod's `Retry`
/// typedef, which is not exported by `flutter_riverpod` — the two are the same
/// type, and spelling it out avoids importing `riverpod`'s internals for a
/// name.
Duration? noRetry(int retryCount, Object error) => null;

/// How many rows a list screen asks for per request.
///
/// The React original's number — `getAllCustomers(25, 0, ...)` and the same
/// `25, 0` in all three sibling screens. The page **size** is unchanged from
/// the original; what is new is a way to ask for the next one, which is what
/// task 4.9 added.
///
/// Kept as a shared constant rather than the four `static const _pageLimit`
/// copies the screens each declared. Four copies of the same number is four
/// places to change it, and one of them is the default every page fetch after
/// the first uses.
const int kListPageSize = 25;

/// Everything one list screen has loaded, plus what it needs to ask for more.
///
/// [items] is the accumulation of every page fetched so far, which is why this
/// is not simply a [PaginatedResponse] — that describes one request's worth, and
/// a screen showing three of them needs all three held at once.
@immutable
class PagedListState<T> {
  const PagedListState({
    required this.items,
    required this.total,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.loadMoreError,
  });

  /// Every row loaded so far, in server order, across all fetched pages.
  final List<T> items;

  /// The server's unpaginated count, when it sent one.
  ///
  /// Clamped to at least [items.length] when it is built — see
  /// [PagedListController._stateFor]. `total` is counted before `limit` is
  /// applied (task 10.15), so it is the whole matching table rather than the
  /// page, which is what makes "is there more" answerable at all.
  final int total;

  /// Whether a further page is in flight.
  final bool isLoadingMore;

  /// Whether another page is worth asking for.
  final bool hasMore;

  /// Why the last attempt to load a further page failed, or null.
  ///
  /// Separate from the provider's own `AsyncError` on purpose. A failure to
  /// load page 3 must not blank the 50 rows already on screen — the rows stay,
  /// the footer says what went wrong, and the user can try again. Folding it
  /// into the provider's error state would take the list down with it.
  final ApiException? loadMoreError;

  /// The same state with [isLoadingMore] changed.
  PagedListState<T> loadingMore() => PagedListState<T>(
    items: items,
    total: total,
    isLoadingMore: true,
    hasMore: hasMore,
  );
}

/// Accumulates pages for one list screen.
///
/// **An `AsyncNotifier` family rather than a `FutureProvider.family`, and the
/// reason is the offset.** The family key is everything *except* the offset —
/// search, sort, organization — and the offset lives here, inside the notifier,
/// so successive pages land in the same instance and append to the same list.
/// Keying on the full query including `offset` would give each page its own
/// provider, and a screen would then have to gather N independent `AsyncValue`s
/// into one list and work out which of them is still loading.
///
/// That also gets the reset for free. Changing the search term produces a
/// different [ListQuery] key, Riverpod builds a *new* notifier, and a new
/// notifier starts at offset 0 with an empty [PagedListState]. No explicit
/// "clear the pages" step, and no way for it to be forgotten — which is the
/// failure mode of an accumulator that resets itself in the wrong place.
///
/// [ListQuery] has value equality for exactly this reason; the screens rebuild
/// a fresh one on every build, and without `==` every unrelated rebuild would be
/// a different key and a fresh fetch.
abstract class PagedListController<T> extends AsyncNotifier<PagedListState<T>> {
  PagedListController(this.baseQuery);

  /// Everything the server filters on. Paging is applied on top of this by
  /// [_query], so a screen builds its query without a `limit` or an `offset`.
  final ListQuery baseQuery;

  /// Fetches one page. The only thing a resource has to supply.
  Future<PaginatedResponse<T>> fetchPage(ListQuery query);

  /// Whether the server has said there is nothing left to send.
  ///
  /// A page shorter than [kListPageSize] is the server saying so. `total` would
  /// be the better signal and is used for display, but it is not something the
  /// client can rely on to be present — `PaginatedResponse` defaults it to `0`
  /// and a count that is missing, zero or stale would each strand the list at
  /// 25 rows with no way past it. A short page cannot lie that way.
  bool _exhausted = false;

  /// Counts how many queries have been issued against this notifier.
  ///
  /// **This exists for one race, and it is worth naming precisely.** A
  /// [loadMore] can be in flight — the user scrolled to the bottom — when the
  /// user deletes a row and the screen calls [reload]. `reload` fetches page 0
  /// and installs it; then the older request, which was issued at offset 25
  /// *before* the delete, arrives and assigns its own result — the pre-delete
  /// rows plus a page computed from stale offsets. The list silently shows rows
  /// that were deleted.
  ///
  /// Both methods capture the counter before their `await` and compare after it,
  /// so a response belonging to a superseded query is dropped instead. `ref.mounted`
  /// does not cover this: it only detects that the notifier was *disposed*, and
  /// [reload] does not dispose this notifier — it is the same one, deliberately,
  /// because the screen keeps watching it.
  int _generation = 0;

  @override
  Future<PagedListState<T>> build() async {
    final page = await fetchPage(_query(0));
    return _stateFor(page, accumulated: const []);
  }

  /// Discards the accumulated pages and refetches from the first.
  ///
  /// What a screen calls after a delete. **Resetting rather than reloading the
  /// page the deleted row was on is deliberate, and offset paging is the
  /// reason.** Removing a row shifts every row after it up by one, so the
  /// boundaries of pages 2 and 3 have both moved and any rows already
  /// accumulated past the deletion are now wrong — a duplicate or a skip
  /// depending on which way it went. There is no way to repair them in place
  /// without refetching, and refetching everything is the whole list. Starting
  /// from page 0 discards them and costs one request.
  ///
  /// This is also what the React original did — `CustomerList.tsx:63` calls
  /// `fetchCustomers()`, which refetched its single fixed page.
  ///
  /// Rows stay on screen while this is in flight. Dropping them would flash the
  /// list for the same reason task 4.14 was filed, and there is nothing here
  /// that makes the old rows *more* wrong than they were a moment ago.
  Future<void> reload() async {
    final current = state.value;
    // Claim the generation before the await. Any `loadMore` already in flight
    // holds an older number and will drop its result rather than install a page
    // computed from offsets that predate this delete. See [_generation].
    final generation = ++_generation;
    _exhausted = false;
    state = AsyncData(
      PagedListState<T>(
        items: current?.items ?? const [],
        total: current?.total ?? 0,
        isLoadingMore: current != null,
        hasMore: current?.hasMore ?? false,
      ),
    );

    try {
      final page = await fetchPage(_query(0));
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(_stateFor(page, accumulated: const []));
    } on ApiException catch (error, stack) {
      if (!ref.mounted || generation != _generation) return;
      // The rows that were there are still there and still true; the fetch
      // failed on top of that. Going to the provider's error state would blank
      // a list that has nothing wrong with it.
      debugPrint('PagedListController.reload: $error');
      debugPrintStack(stackTrace: stack);
      state = AsyncData(
        PagedListState<T>(
          items: current?.items ?? const [],
          total: current?.total ?? 0,
          hasMore: current?.hasMore ?? false,
          loadMoreError: error,
        ),
      );
    }
  }

  /// Appends the next page, if there is one.
  ///
  /// Safe to call from a scroll listener, which fires far more often than a
  /// user pages: the guards below make every redundant call a no-op rather than
  /// a request.
  ///
  /// Offset paging has the usual weakness — a row inserted or deleted between
  /// two requests shifts everything after it, so a page boundary can skip or
  /// repeat a row. That belongs to the API rather than to this code: the
  /// endpoint is offset/limit with no cursor (see [PaginatedResponse]), so there
  /// is nothing better to ask for.
  Future<void> loadMore() async {
    final current = state.value;
    // `state.value` is null during the first load and after a failure, and
    // either way there is nothing to append to.
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    // Not `++_generation`. A page is additive rather than a replacement, so
    // claiming a new generation here would make this call invalidate *itself*,
    // and — worse — make two legitimate concurrent loads mutually invalidating.
    // The generation only moves on a [reload], which is the operation that
    // discards rows.
    final generation = _generation;

    // Set before the await, not after, so a second call arriving while this one
    // is in flight sees it. A scroll listener fires continuously.
    state = AsyncData(current.loadingMore());

    try {
      final page = await fetchPage(_query(current.items.length));
      // The screen can be gone — a new search term makes a new notifier and
      // disposes this one — and assigning state after disposal throws. Same
      // guard `AuthController.refresh` uses for the same reason.
      //
      // The second condition is the delete race: a [reload] landed while this
      // request was in flight, so these rows were computed from offsets that no
      // longer mean anything. See [_generation].
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(_stateFor(page, accumulated: current.items));
    } on ApiException catch (error) {
      if (!ref.mounted || generation != _generation) return;
      // Back to the rows we had, with the failure recorded for the footer. The
      // list does not go blank because its fourth page did not arrive.
      state = AsyncData(
        PagedListState<T>(
          items: current.items,
          total: current.total,
          hasMore: current.hasMore,
          loadMoreError: error,
        ),
      );
    }
  }

  /// The screen's query, with this page's paging applied.
  ListQuery _query(int offset) =>
      baseQuery.copyWith(limit: kListPageSize, offset: offset);

  /// Folds a freshly fetched page into what is already loaded.
  PagedListState<T> _stateFor(
    PaginatedResponse<T> page, {
    required List<T> accumulated,
  }) {
    _exhausted = page.items.length < kListPageSize;
    final items = [...accumulated, ...page.items];

    return PagedListState<T>(
      items: items,
      // Clamped: a `total` below what we are holding is either stale or was
      // never a count at all, and either way it would render as "Showing 50 of
      // 12" and put the list in a state it cannot explain.
      total: page.total > items.length ? page.total : items.length,
      hasMore: !_exhausted,
    );
  }
}
