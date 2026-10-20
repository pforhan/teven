import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/list_query.dart';
import '../../models/common.dart';
import '../../models/event.dart';
import 'paged_list.dart';
import 'service_providers.dart';

/// How many events the calendar asks for in a month.
///
/// `EventCalendar.tsx:88` calls `getAllEvents(1000, …)`, so this is the
/// original's number rather than one chosen here.
///
/// **It is a large number for this endpoint**, and the port is not in a position
/// to lower it without changing what the calendar shows. `EventResponse`
/// embeds the customer, the organization, every inventory line and every RSVP,
/// and the server applies no compression — task 1.18 sets a default of 10 for
/// exactly that reason. A month with fifty events is a large response.
///
/// Note what the cap is and is not for. It is **not** pagination: there is no
/// second page, and a month holding more than a thousand events would silently
/// render short. It is a ceiling inherited from the original, kept because
/// dropping it would be a visible behaviour change rather than a fix. The
/// events *list* (task 7.5) is the one that pages properly, via
/// [eventListProvider].
const int kCalendarEventLimit = 1000;

/// The event list, accumulating a page at a time.
///
/// Task 7.5. See [PagedListController] for the shared shape and
/// `customer_list.dart` for the simplest instance of it.
///
/// **Two things about events make this heavier than the other four lists**, and
/// neither is visible from the call site:
///
/// - **A page of 25 events is much larger than a page of 25 of anything else.**
///   Each row embeds a customer, an organization, an inventory list and an
///   RSVP list, with no server-side compression. That is the argument for
///   [EventService.defaultLimit] being 10 rather than the [kListPageSize] the
///   other lists share, and the reason to treat the page size here as a
///   starting point rather than a verified one.
/// - **The one sortable header this screen shows does nothing.** `sortBy` is
///   accepted by `EventRoutes.kt` and never read by `EventDao`
///   (task 10.11); `sortOrder` *does* work and defaults to `asc`. The sort
///   control is reproduced anyway, on the same terms as the three customer
///   headers the server ignores — see task 4.11, which decided that hiding a
///   control the original shows is a worse divergence than leaving it inert.
final eventListProvider = AsyncNotifierProvider.autoDispose
    .family<PagedEventList, PagedListState<EventResponse>, ListQuery>(
      PagedEventList.new,
      retry: noRetry,
    );

class PagedEventList extends PagedListController<EventResponse> {
  PagedEventList(super.baseQuery);

  @override
  Future<PaginatedResponse<EventResponse>> fetchPage(ListQuery query) =>
      ref.watch(eventServiceProvider).getAllEvents(query);
}

/// One month of events for the calendar grid.
///
/// **A plain [FutureProvider.family] rather than a [PagedListController], and
/// the difference is the endpoint.** The calendar asks for a single window
/// (`startDate`/`endDate` around the visible month) with no offset, and
/// react-big-calendar had no paging concept either — it held the whole range it
/// had been given. There is no second page to accumulate and no "load more" to
/// hang off a grid, so the whole pagination machinery would be inert here.
///
/// Keyed on a [ListQuery] rather than a bespoke month key so it gets value
/// equality for free, and so the calendar screen builds the same object shape
/// the other list screens do. The screen is what turns a `DateTime` into the
/// first and last day of its month; see `EventCalendarScreen._buildQuery`.
final calendarEventsProvider = FutureProvider.autoDispose
    .family<List<EventResponse>, ListQuery>((ref, query) async {
      final page = await ref.watch(eventServiceProvider).getAllEvents(query);
      return page.items;
    }, retry: noRetry);
