import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/list_query.dart';
import '../models/common.dart';
import '../models/invitation.dart';
import '../models/user.dart';
import 'paged_list.dart';
import 'service_providers.dart';

/// The users table, accumulating a page at a time.
///
/// The same shape as `customerListProvider` and for the same reason: the screen
/// owns every input — the search term, the sort column, the selected
/// organization — and changing one produces a different [ListQuery] key, which
/// is what resets the accumulated pages. See [PagedListController].
///
/// The organization scoping is the one thing here that a copy of the customer
/// or inventory screen would get right by accident and this one has to earn: the
/// original user list passed the selected organization's id, so the super-admin's
/// switcher narrows this list the same way it narrows those two.
final userPageProvider = AsyncNotifierProvider.autoDispose
    .family<PagedUserList, PagedListState<UserResponse>, ListQuery>(
      PagedUserList.new,
      retry: noRetry,
    );

class PagedUserList extends PagedListController<UserResponse> {
  PagedUserList(super.baseQuery);

  @override
  Future<PaginatedResponse<UserResponse>> fetchPage(ListQuery query) =>
      ref.watch(userServiceProvider).getAllUsers(query);
}

/// Outstanding invitations, or an empty list.
///
/// The original user list fetched these only when the caller could manage users,
/// and rendered the table only when the list came back non-empty. Both
/// conditions are applied at the call site rather than here: an unauthorized
/// fetch would 403, and a provider cannot read the permission gate without
/// making this a `Provider` that rebuilds whenever the session does.
///
/// **Not paged.** `GET /api/invitations` returns a bare list rather than a
/// `PaginatedResponse`, but it now accepts sort parameters so the UI can sort
/// by organization in all-org views.
final unusedInvitationsProvider = FutureProvider.autoDispose
    .family<List<InvitationResponse>, ({String? sortBy, String? sortOrder})>(
      (ref, sort) => ref
          .watch(invitationServiceProvider)
          .getUnusedInvitations(sortBy: sort.sortBy, sortOrder: sort.sortOrder),
    );
