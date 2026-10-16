import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show
        AsyncValue,
        AsyncValueExtensions,
        ConsumerState,
        ConsumerStatefulWidget;
// `ProviderListenable` is not exported by `flutter_riverpod.dart` — that library
// exports `ProviderListenableSelect` and its relatives but not the base
// interface — so it comes from `flutter_riverpod/misc.dart`. `package:riverpod`
// also exports it, but reaching past `flutter_riverpod` for it trips
// `depend_on_referenced_packages` and would mean declaring `riverpod` as a direct
// dependency purely to name one type that is already in the graph.
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../core/api/api_exception.dart';
import '../core/services/list_query.dart';
import '../providers/paged_list.dart';
import 'error_display.dart';
import 'responsive_list_view.dart';

/// A list screen's body: the rows, and the footer that asks for the next page.
///
/// **Infinite scroll, with a button as the floor rather than the mechanism.**
/// Scrolling near the bottom requests the next page automatically, which is what
/// a list that grows as you read it should do — the user should not have to
/// notice a page boundary and go looking for a control. But the trigger is a
/// [NotificationListener] on a scroll position, and that has two failure modes
/// worth being honest about:
///
/// - **It cannot reach pages at all if the rows fit on screen.** A short list
///   has nothing to scroll, so nothing fires. This happens on a wide window with
///   a tall viewport, and on any screen holding fewer rows than fit.
/// - **It is invisible.** Nothing says a second page exists until it starts
///   arriving.
///
/// So the footer always shows a "Load more" button while more remains, and the
/// scroll listener is an accelerant on top of it rather than the only way
/// through. A button that is redundant most of the time is much cheaper than a
/// user stuck at row 25 wondering whether the list ends there.
///
/// The scroll threshold is [loadMoreThreshold] rather than the very bottom, so
/// the request is in flight before the user reaches the end and the rows are
/// usually already there. Fetching only on arrival at the boundary shows a
/// spinner every single time.
class PagedListView<T> extends StatelessWidget {
  const PagedListView({
    super.key,
    required this.state,
    required this.columns,
    required this.idOf,
    required this.loadMore,
    this.actions,
    this.sortBy,
    this.sortOrder,
    this.onSort,
    this.emptyMessage = 'Nothing to show.',
    this.revealActionsOnHover,
    this.stale = false,
    this.filtered = false,
  });

  /// The rows loaded so far, and whether more are coming.
  final PagedListState<T> state;

  final List<ListColumn<T>> columns;
  final Object Function(T item) idOf;

  /// Requests the next page, from the footer's button.
  ///
  /// **The same callback [PagedScrollView] is given for scrolling.** One
  /// handler, two triggers — which is what keeps the automatic and manual paths
  /// from drifting, and is why the button needs no knowledge of what the scroll
  /// listener does. It must tolerate being called when there is nothing to
  /// fetch, which [PagedListController.loadMore] does.
  final VoidCallback loadMore;

  final List<ListRowAction> Function(BuildContext context, T item)? actions;
  final String? sortBy;
  final SortOrder? sortOrder;
  final ValueChanged<String>? onSort;
  final String emptyMessage;
  final bool? revealActionsOnHover;

  /// Whether the rows on screen are the result of an active search.
  ///
  /// Only affects the wording of the count. "Showing all 2" is ambiguous in a
  /// way that matters once a filter is on: two of *what*? The count is the
  /// number the server matched, not the size of the table, and on a screen
  /// listing a large collection "Showing all 2" reads as though the collection
  /// holds two rows. Suffixing **filtered** says which number it is, and it is
  /// the only place the distinction surfaces — the rows look identical either
  /// way.
  final bool filtered;

  /// Whether these rows are the answer to the query currently being displayed.
  ///
  /// False once a newer query has started and before it lands — whether it is
  /// still in flight or has failed. **One flag, not three states**, and the
  /// reason is worth recording because the three-state version it replaced was
  /// written for a good reason and was still the wrong shape.
  ///
  /// It began as a single boolean covering both "refreshing" and "failed", which
  /// was wrong: the failure path rendered a progress bar that never stopped, an
  /// indeterminate animation on a screen that had already given up, and it made
  /// `pumpAndSettle` hang forever in the widget tests. So it became an enum —
  /// `current`, `refreshing`, `stale` — with a bar for one and not the other.
  ///
  /// **Then the bar went, and `refreshing` and `stale` turned out to render
  /// identically**, because the only thing that had distinguished them was the
  /// decoration. The enum was carrying a distinction that no longer existed. A
  /// browser check found why the bar had to go: it was inserted above the card,
  /// so it pushed the whole list down by its own height for the duration of
  /// every search — a 2px version of the very flash task 4.14 exists to remove.
  /// **The progress indicator was moving the thing it was reporting on.**
  ///
  /// What survives is the part with a real justification: the footer is
  /// suppressed, because "Showing 25 of 137" and a "Load more" button describe
  /// the *retained* result, and during a search that result is not what the user
  /// asked for — a count for the wrong filter, and a button that would page the
  /// previous query. The same holds of a failed query, for the same reason.
  ///
  /// **There is now no visual indication that the rows are stale**, which is
  /// what `TableView.tsx` did: it had no loading state at all, so a search was
  /// silent until the rows changed. That is the behaviour being restored, and it
  /// is a deliberate trade rather than an omission.
  final bool stale;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ResponsiveListView<T>(
        data: state.items,
        columns: columns,
        idOf: idOf,
        actions: actions,
        sortBy: sortBy,
        sortOrder: sortOrder,
        onSort: onSort,
        emptyMessage: emptyMessage,
        revealActionsOnHover: revealActionsOnHover,
      ),
      // An empty list has nothing to page: `hasMore` is only ever true of a
      // list that came back short, and a genuinely empty result is not short.
      // Nor is there anything to page while these rows are not the answer.
      if (state.items.isNotEmpty && !stale)
        _Footer<T>(state: state, loadMore: loadMore, filtered: filtered),
    ],
  );
}

/// The scroll view a paginated list screen scrolls in.
///
/// **This widget exists, rather than a `NotificationListener` inside
/// [PagedListView], because of where the notification has to be caught.** Scroll
/// notifications are dispatched at the [Scrollable] and bubble *upward*, so a
/// listener only sees them if it is an **ancestor** of the scroll view. The
/// screen owns the `SingleChildScrollView` — it holds the heading, the search
/// field and the list in one scrolling column — which makes
/// [PagedListView] a *descendant* of the scrollable and therefore structurally
/// unable to hear about scrolling, however much it listens for it.
///
/// That failure is silent and total. The footer still renders and the button
/// still works, so the list pages perfectly well; only the automatic part never
/// fires, and nothing anywhere reports a problem. It was caught by the widget
/// test that scrolls rather than taps, which is the argument for having both.
///
/// Wrapping the scroll view rather than inlining a listener per screen also
/// keeps [loadMoreThreshold] in one place, which is the value most likely to be
/// wanted changed.
class PagedScrollView extends StatelessWidget {
  const PagedScrollView({
    super.key,
    required this.onLoadMore,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  /// Requests the next page. Called by the scroll listener and by the footer
  /// button, so it must tolerate being called when there is nothing to fetch —
  /// [PagedListController.loadMore] does.
  final VoidCallback onLoadMore;

  final Widget child;

  /// The screen's own content padding — `EdgeInsets.all(16)` on all four, and a
  /// parameter only so a screen with a different one is not editing a default.
  final EdgeInsets padding;

  @override
  Widget build(
    BuildContext context,
  ) => NotificationListener<ScrollNotification>(
    // `false` — the list does not consume the notification. Returning `true`
    // here would stop the scroll view from receiving it and, with it, the
    // scrolling itself.
    onNotification: (notification) {
      final metrics = notification.metrics;
      // No dimensions yet means the first layout has not happened, so
      // `maxScrollExtent` is 0 and every position looks like "at the end" —
      // which would fire a request for a list that has not been measured.
      if (!metrics.hasContentDimensions) return false;
      if (metrics.pixels >= metrics.maxScrollExtent - loadMoreThreshold) {
        onLoadMore();
      }
      return false;
    },
    child: SingleChildScrollView(padding: padding, child: child),
  );
}

/// How close to the end of the list a scroll gets before the next page is asked
/// for.
///
/// Roughly two rows of the table's 48px, which is enough that a request has
/// usually landed by the time the user reaches the boundary. A larger value
/// starts sooner and would prefetch pages the user may never scroll to — each
/// one a request, and on the inventory list a request whose rows embed an
/// unbounded event history (task 10.21).
const double loadMoreThreshold = 100;

/// The count, the progress, or the button.
///
/// Which of the three is shown, and why only one at a time:
///
/// - **Count** while there is more to come. `Showing 25 of 137` is the only
///   part of this the user could not work out unaided, and it is also what makes
///   a list that has not finished loading legible as such rather than looking
///   like the whole thing.
/// - **A spinner** replaces it in place while the request is in flight, so the
///   button does not sit there looking tappable and then do nothing when it is
///   tapped. The count goes at the same moment; keeping it would mean the row
///   changing width mid-request.
/// - **The button** otherwise, so the next page is reachable without scrolling
///   and without knowing the list is scrollable. See the class doc for why this
///   is not purely a fallback.
class _Footer<T> extends StatelessWidget {
  const _Footer({
    required this.state,
    required this.loadMore,
    required this.filtered,
  });

  final PagedListState<T> state;
  final VoidCallback loadMore;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Suffix on both counts, for the reason on [PagedListView.filtered]: with a
    // filter on, the number is how many rows *matched*, not how many exist.
    final suffix = filtered ? ' filtered' : '';

    // A failed page leaves the rows above untouched, so the failure is reported
    // here rather than replacing the list. The message is the server's, for the
    // same reason every other error on these screens uses it.
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ErrorDisplay.fromException(state.loadMoreError!),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: loadMore,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ),
          ],
        ),
      );
    }

    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!state.hasMore) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          'Showing all ${state.total}$suffix',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Text(
            'Showing ${state.items.length} of ${state.total}$suffix',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: loadMore,
            icon: const Icon(Icons.expand_more),
            label: const Text('Load more'),
          ),
        ],
      ),
    );
  }
}

/// A list screen's rows, keeping the previous result on screen while a new query
/// loads. Task 4.14.
///
/// **What the React original did, precisely, because "it kept the rows" is not
/// the whole of it.** `TableView.tsx` has *no loading state at all* — it renders
/// `data` unconditionally, and `CustomerList.tsx:34` sets state only inside the
/// `try`, so a failed or in-flight fetch left `customers` untouched. Two
/// consequences, and the port had both wrong before this:
///
/// 1. **Rows stay put during a search.** The whole card used to be replaced by
///    a spinner, so the heading, the column headers and every row blinked out
///    and back on each debounced keystroke. That is the filed symptom.
/// 2. **On failure the error appears *above* the stale rows, not instead of
///    them.** `TableView.tsx:40` and `:42` are siblings inside the same card
///    body, so React rendered the banner and the previous table together. The
///    port replaced the list with the error, which is a divergence this task
///    did not originally mention.
///
/// **How the retention works, and why it is a field rather than a provider.** A
/// new search term is a different `ListQuery` key and therefore a *different*
/// provider, so Riverpod has already discarded the old result by the time the
/// new query starts — there is no previous value to read out of the
/// [AsyncValue], and no amount of `skipLoadingOnRefresh` will conjure one. The
/// previous list is therefore kept here, in this widget's state.
///
/// The alternative was task 4.14's option 3, "retain the last value across
/// family keys with Riverpod's keep-alive link pattern" — hold the old provider
/// alive so its value survives. That works too and is arguably more
/// "correct-looking", but it retains a *provider*, and keeping a whole live
/// provider alive to preserve a list of rows is more machinery than copying
/// twenty-five of them into a field. One screen's worth of retention does not
/// need a container-level lifetime.
///
/// **The retained rows are stale, and they are labelled as such by the bar
/// rather than by hiding.** They are the previous *search's* rows, so for a
/// moment they are not what the user asked for — which is precisely what the
/// React original showed, and the reason that behaviour was worth copying. A
/// list that says nothing while it reloads is worse than one that shows what it
/// had a moment ago and admits it is refreshing.
class PagedListSection<T> extends ConsumerStatefulWidget {
  const PagedListSection({
    super.key,
    required this.provider,
    required this.loadMore,
    required this.columns,
    required this.idOf,
    this.actions,
    this.sortBy,
    this.sortOrder,
    this.onSort,
    this.emptyMessage = 'Nothing to show.',
    this.revealActionsOnHover,
    this.filtered = false,
  });

  /// The list being watched.
  ///
  /// A [ProviderListenable] rather than a resolved `AsyncValue` because
  /// **watching has to happen here**, not in the screen: the screen watches the
  /// provider to build the query, and a new query means a new provider, so a
  /// screen that handed over a snapshot would have nothing to retain. Passing
  /// the provider itself is what lets the previous value be captured before it is
  /// replaced.
  final ProviderListenable<AsyncValue<PagedListState<T>>> provider;

  /// Requests the next page — the same handler [PagedScrollView] uses.
  final VoidCallback loadMore;

  final List<ListColumn<T>> columns;
  final Object Function(T item) idOf;
  final List<ListRowAction> Function(BuildContext context, T item)? actions;
  final String? sortBy;
  final SortOrder? sortOrder;
  final ValueChanged<String>? onSort;
  final String emptyMessage;
  final bool? revealActionsOnHover;

  /// Whether the screen's search box holds a term. Only reaches the footer, to
  /// word its count — see [PagedListView.filtered].
  final bool filtered;

  @override
  ConsumerState<PagedListSection<T>> createState() =>
      _PagedListSectionState<T>();
}

class _PagedListSectionState<T> extends ConsumerState<PagedListSection<T>> {
  /// The last list that actually resolved, kept while a newer query is in
  /// flight or has failed.
  ///
  /// Never cleared. A user who searches "globex" and then clears the box gets
  /// the globex rows back while the unfiltered query loads, which is the same
  /// behaviour as not clearing it at all — and a retention scheme that reset
  /// itself would reintroduce exactly the flash this exists to remove.
  PagedListState<T>? _retained;

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(widget.provider);

    // Captured during build rather than in a listener: assigning to a field is
    // not a `setState`, so this does not schedule a frame, and reading it here
    // means the value is retained on the very first frame it resolves rather
    // than one frame later. A `ref.listen` would work too and would need its own
    // test to prove it fires on the initial value.
    final resolved = current.value;
    if (resolved != null) _retained = resolved;

    final retained = _retained;

    // Data is authoritative whenever there is any — including a refresh that
    // carried its previous value, where the rows on screen are the right ones
    // and only the pagination state is moving.
    if (resolved != null) {
      return _list(resolved);
    }

    // An error with something retained: the banner above the stale rows, which
    // is what `TableView.tsx:40,42` renders. With nothing retained there is
    // nothing to sit under it.
    //
    // `value`/`error`/`isLoading` rather than `hasValue`/`hasError`: in
    // Riverpod 3 those two live on an `@internal` extension, and reaching them
    // means importing something not meant to be used.
    final error = current.error;
    if (error != null) {
      final banner = ErrorDisplay.fromException(
        error is ApiException ? error : ApiRequestException('$error'),
      );
      if (retained == null) return banner;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          banner,
          const SizedBox(height: 16),
          _list(retained, stale: true),
        ],
      );
    }

    // Loading, with something retained: the rows stay and a bar says they are
    // about to change. This is task 4.14's fix.
    if (current.isLoading && retained != null) {
      return _list(retained, stale: true);
    }

    // A first load, or a query that failed with nothing to show. A spinner is
    // correct here and honest: there are no rows to keep, and the empty-state
    // message would claim there is nothing to find when the truth is that
    // nothing has arrived yet.
    return const Center(child: CircularProgressIndicator());
  }

  Widget _list(PagedListState<T> state, {bool stale = false}) =>
      PagedListView<T>(
        state: state,
        columns: widget.columns,
        idOf: widget.idOf,
        loadMore: widget.loadMore,
        actions: widget.actions,
        sortBy: widget.sortBy,
        sortOrder: widget.sortOrder,
        onSort: widget.onSort,
        emptyMessage: widget.emptyMessage,
        revealActionsOnHover: widget.revealActionsOnHover,
        stale: stale,
        filtered: widget.filtered,
      );
}
