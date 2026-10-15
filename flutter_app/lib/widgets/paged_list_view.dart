import 'package:flutter/material.dart';
// `AsyncValueExtensions` is not optional here: `when` is an extension method,
// not a member of `AsyncValue`, so importing only the class leaves `state.when`
// undefined with a message that points at the wrong thing entirely.
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show AsyncValue, AsyncValueExtensions;

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
      if (state.items.isNotEmpty) _Footer<T>(state: state, loadMore: loadMore),
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
  const _Footer({required this.state, required this.loadMore});

  final PagedListState<T> state;
  final VoidCallback loadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          'Showing all ${state.total}',
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
            'Showing ${state.items.length} of ${state.total}',
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

/// Builds the loading, error and loaded states of a [PagedListState].
///
/// Extracted so the four list screens agree on **when** a spinner appears rather
/// than each re-deriving it, and so the rule below is stated once.
///
/// **A spinner replaces the list only when there is nothing to show.** A failed
/// or in-flight *first* page has no rows behind it, so there is nothing to keep;
/// once any page has landed, a later request shows a footer instead and the rows
/// stay. That is task 4.14's fix, and it comes for free here rather than as a
/// separate mechanism: an accumulating list already holds the previous result,
/// so keeping it visible is the absence of work rather than a retention scheme.
class PagedListBody<T> extends StatelessWidget {
  const PagedListBody({
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
  });

  /// The provider's value. An `AsyncValue` rather than a bare state so the
  /// screen passes what it already watched, and this widget does not need to
  /// know which resource it is rendering.
  final AsyncValue<PagedListState<T>> state;

  final List<ListColumn<T>> columns;
  final Object Function(T item) idOf;
  final VoidCallback loadMore;
  final List<ListRowAction> Function(BuildContext context, T item)? actions;
  final String? sortBy;
  final SortOrder? sortOrder;
  final ValueChanged<String>? onSort;
  final String emptyMessage;
  final bool? revealActionsOnHover;

  @override
  Widget build(BuildContext context) => state.when(
    // `skipLoadingOnRefresh: false` because the default — true — routes a
    // refresh that *kept* its previous value to `data` instead. That is the
    // right default elsewhere, but here it would hide the in-flight state of a
    // reload that does have rows behind it, and the footer would never appear.
    skipLoadingOnRefresh: false,
    loading: () => const Center(child: CircularProgressIndicator()),
    // The same wrapping every list screen already does: `ApiClient` raises the
    // sealed `ApiException` hierarchy, and anything reaching here as a bare
    // object is a programming error rather than a server message.
    error: (error, _) => ErrorDisplay.fromException(
      error is ApiException ? error : ApiRequestException('$error'),
    ),
    data: (data) => PagedListView<T>(
      state: data,
      columns: columns,
      idOf: idOf,
      loadMore: loadMore,
      actions: actions,
      sortBy: sortBy,
      sortOrder: sortOrder,
      onSort: onSort,
      emptyMessage: emptyMessage,
      revealActionsOnHover: revealActionsOnHover,
    ),
  );
}
