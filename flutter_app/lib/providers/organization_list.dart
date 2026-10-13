import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/list_query.dart';
import '../models/organization.dart';
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
