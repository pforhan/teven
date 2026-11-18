import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/list_query.dart';
import '../../models/common.dart';
import '../../models/event.dart';
import 'paged_list.dart';
import 'service_providers.dart';

/// How many events the calendar asks for in a month.
///
/// The calendar queries a bounded date range, so it requests an explicit high
/// limit rather than relying on the server default. The server allows a higher
/// cap for range-bounded event queries than for general lists.
const int kCalendarEventLimit = 500;

/// The event list, accumulating a page at a time.
///
/// See [PagedListController] for the shared shape and
/// `customer_list.dart` for the simplest instance of it.
///
/// **Two things about events make this heavier than the other four lists**, and
/// neither is visible from the call site:
///
/// - **A page of events is larger than a page of other list rows.** Each row
/// embeds a customer, an organization, an inventory list and an RSVP list,
/// with no server-side compression. The server now applies a default page size
/// when omitted; callers that need a specific page size should request it
/// explicitly.
/// - **`sortBy` and `sortOrder` are forwarded to the server.** The event list
/// endpoint supports sorting by start time (`startsAt`) and `title`.
/// `sortOrder` *does* work and defaults to `asc`. The sort
/// control is reproduced anyway, on the same terms as the three customer
/// headers the server ignores — see which decided that hiding a
/// control the original shows is a worse divergence than leaving it inert.
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
