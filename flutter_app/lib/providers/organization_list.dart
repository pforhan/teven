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
///
/// **`retry: noRetry`, for the same reason [organizationPageProvider] sets it.**
/// A `FutureProvider` left on the default policy retries a failed build on an
/// exponential backoff, and the first retry's 800ms timer outlives the widget
/// test that provoked the failure — Flutter fails the test on the pending timer
/// rather than on any assertion, which reads as a leak in the test harness
/// rather than as the retry it is. A failed organization fetch is also not
/// transient in a way worth hiding: it is a 403 or a 404, and retrying it
/// silently would re-request on a screen that has already told the user it
/// failed.
final organizationListProvider = FutureProvider<List<OrganizationResponse>>((
  ref,
) async {
  final page = await ref
      .watch(organizationServiceProvider)
      .getAllOrganizations(const ListQuery(limit: 1000));
  return page.items;
}, retry: noRetry);

/// The organizations, or an empty list while loading or after a failure.
///
/// For render sites that simply have nothing to show yet — the picker's empty
/// state, the dropdown's disabled state. A failure is *not* silently an empty
/// list anywhere the user could mistake it for "no organizations exist"; see
/// `QuickOrganizationPicker`, which surfaces the error itself.
final organizationsProvider = Provider<List<OrganizationResponse>>(
  (ref) => ref.watch(organizationListProvider).value ?? const [],
);

/// [loaded], with [selected] appended when it is not already among them.
///
/// **`DropdownButton` and `DropdownButtonFormField` assert that the value has a
/// matching item**, and both the chrome's switcher and the customer forms hit
/// that. The React original gets it wrong in both directions: it renders
/// `<select value={selected.organizationId}>` with options built in a
/// `useEffect`, so on the first render — and again on every render before that
/// fetch resolves — the value names an option that does not exist. A browser
/// quietly shows the first option instead; Flutter takes the screen down.
///
/// The list is empty until it resolves, so folding the selection in means the
/// control always has an item for whatever it currently says is selected. An
/// organization that has since been deleted keeps appearing once, which is a
/// smaller lie than pretending the user never chose it.
///
/// Lives here rather than beside either caller because by Phase 5 there are
/// three: the rail's dropdown, and the two customer forms. Phase 3 wrote it as
/// a private function and hit the same assertion again while porting the first
/// form that needed it — which is the argument for a shared home.
List<OrganizationResponse> organizationsIncluding(
  List<OrganizationResponse> loaded,
  OrganizationResponse? selected,
) {
  if (selected == null) {
    return loaded;
  }
  for (final organization in loaded) {
    if (organization.organizationId == selected.organizationId) {
      return loaded;
    }
  }
  return [...loaded, selected];
}

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
    >(PagedOrganizationList.new, retry: noRetry);

class PagedOrganizationList extends PagedListController<OrganizationResponse> {
  PagedOrganizationList(super.baseQuery);

  @override
  Future<PaginatedResponse<OrganizationResponse>> fetchPage(ListQuery query) =>
      ref.watch(organizationServiceProvider).getAllOrganizations(query);
}
