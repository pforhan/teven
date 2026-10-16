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
/// or inventory screen would get right by accident and this one has to earn:
/// `UserList.tsx:39` passes `selectedOrganization?.organizationId`, so the
/// super-admin's switcher narrows this list the same way it narrows those two.
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
/// [UserList.tsx:53-67] fetches these only when the caller can manage users,
/// and the screen renders the table only when the list comes back non-empty
/// (`UserList.tsx:223`). Both conditions are applied at the call site rather
/// than here: an unauthorized fetch would 403, and a provider cannot read the
/// permission gate without making this a `Provider` that rebuilds whenever the
/// session does.
///
/// **Not a family and not paged.** `GET /api/invitations` takes no query
/// parameters at all and returns a bare list rather than a `PaginatedResponse`.
final unusedInvitationsProvider =
    FutureProvider.autoDispose<List<InvitationResponse>>(
      (ref) => ref.watch(invitationServiceProvider).getUnusedInvitations(),
    );
