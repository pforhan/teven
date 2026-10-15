import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/list_query.dart';
import '../models/common.dart';
import '../models/organization.dart';
import 'paged_list.dart';
import 'service_providers.dart';

/// Every organization, for the super-admin's switcher.
///
/// Both callers in the React app — `OrganizationSelector.tsx:15` and
/// `QuickOrganizationPickerModal.tsx:23` — fetch the same list with the same
/// hard-coded `1000` limit, so it is fetched once here rather than twice.
///
/// The limit is explicit and load-bearing: task 10.15 records that omitting
/// `limit` applies **no cap at all** server-side, so an unparameterized request
/// returns the whole table. `1000` is the React app's number, kept as-is.
final organizationListProvider = FutureProvider<List<OrganizationResponse>>((
  ref,
) async {
  final page = await ref
      .watch(organizationServiceProvider)
      .getAllOrganizations(const ListQuery(limit: 1000));
  return page.items;
});

/// The organizations, or an empty list while loading or after a failure.
///
/// For render sites that simply have nothing to show yet — the picker's empty
/// state, the dropdown's disabled state. A failure is *not* silently an empty
/// list anywhere the user could mistake it for "no organizations exist"; see
/// `QuickOrganizationPicker`, which surfaces the error itself.
final organizationsProvider = Provider<List<OrganizationResponse>>(
  (ref) => ref.watch(organizationListProvider).value ?? const [],
);

/// The organization list screen's rows, accumulating a page at a time.
///
/// Separate from [organizationListProvider] because the two want different
/// things from the same endpoint. The switcher wants *all* of them and settles
/// for 1000; the list screen wants a page at a time, sorted and filtered, and
/// re-queries on every keystroke of its search box. One provider for both would
/// either cap the switcher at 25 or give the list screen the whole table every
/// time someone typed a letter.
///
/// That separation is now load-bearing in a way it was not before: this is the
/// screen whose organization scoping is *deliberately absent* (see
/// `OrganizationListScreen`), while the switcher above scopes nothing either but
/// fetches for a different reason. Sharing one provider would make it very easy
/// for a later change to scope this screen by the super-admin's selection and
/// hide every organization but one from the list meant to show all of them.
final organizationPageProvider = AsyncNotifierProvider.autoDispose
    .family<
      PagedOrganizationList,
      PagedListState<OrganizationResponse>,
      ListQuery
    >(PagedOrganizationList.new);

class PagedOrganizationList extends PagedListController<OrganizationResponse> {
  PagedOrganizationList(super.baseQuery);

  @override
  Future<PaginatedResponse<OrganizationResponse>> fetchPage(ListQuery query) =>
      ref.watch(organizationServiceProvider).getAllOrganizations(query);
}
