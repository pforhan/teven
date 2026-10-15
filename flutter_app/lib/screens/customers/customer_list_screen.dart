import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';

import '../../core/services/list_query.dart';
import '../../models/customer.dart';
import '../../models/organization.dart';
import '../../models/permissions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/customer_list.dart';
import '../../providers/organization_controller.dart';
import '../../providers/service_providers.dart';
import '../../routing/app_router.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/debounced_search_field.dart';
import '../../widgets/error_display.dart';
import '../../widgets/list_screen_header.dart';
import '../../widgets/paged_list_view.dart';
import '../../widgets/record_link_button.dart';
import '../../widgets/responsive_list_view.dart';

/// The customer list.
///
/// `CustomerList.tsx` (134 lines). Search, sort, create and delete, plus
/// pagination — the one thing here the React original does not have.
///
/// **The paging is new rather than ported, and it is worth being clear which
/// part of it is not.** `CustomerList.tsx:27` fetched `getAllCustomers(25, 0,
/// …)` and there is no control anywhere in the React app to reach row 26, so
/// task 4.9 recorded "premise did not hold" and closed. The page *size* is
/// still 25 — [kListPageSize], shared by all four list screens — because that is
/// what the original asked for. What is new is that there is now a way to ask
/// for the next page, and that it is the same shape on every list screen rather
/// than four private `static const _pageLimit` copies.
///
/// The row actions are hover-revealed in the React original
/// (`CustomerList.tsx:79`), which is unreachable on a phone. The shared
/// [ResponsiveListView] resolves that: hover on a pointer, always visible in a
/// card.
class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  String _searchTerm = '';
  String _sortBy = 'name';
  SortOrder _sortOrder = SortOrder.asc;

  /// The query built during the last build, kept so event handlers — "load
  /// more", "reload after a delete" — can reach the same provider the screen is
  /// watching.
  ///
  /// Rebuilding it in the handler instead would mean repeating the scoping rules
  /// in a second place, and getting one of them subtly different is the kind of
  /// bug that only shows up after a delete: the list reloads unfiltered, or
  /// reloads the wrong organization's rows. One construction, one use.
  ListQuery? _query;

  /// An error from a mutation — a failed delete, which the list itself does not
  /// re-render.
  ///
  /// The React original held one `error` for both the fetch and the delete and
  /// rendered it through `TableView`. Here the fetch's error lives in the
  /// provider, so only the mutation's needs a field.
  ApiException? _actionError;

  /// `CustomerList.tsx:50-56`: re-tapping the active column reverses it, and a
  /// different column starts ascending.
  void _onSort(String key) {
    setState(() {
      if (_sortBy == key) {
        _sortOrder = _sortOrder == SortOrder.asc
            ? SortOrder.desc
            : SortOrder.asc;
      } else {
        _sortBy = key;
        _sortOrder = SortOrder.asc;
      }
    });
  }

  /// The delete confirmation. `CustomerList.tsx:60`.
  ///
  /// The dialog is shared — see [confirmDestructiveAction] — and what stays here
  /// is the part that is specific to this screen: the service call, the refetch,
  /// and where a failure is shown.
  Future<void> _confirmDelete(CustomerResponse customer) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete customer',
      message:
          'Are you sure you want to delete ${customer.name}? This cannot be '
          'undone.',
    );

    if (!confirmed || !mounted) return;

    try {
      await ref
          .read(customerServiceProvider)
          .deleteCustomer(customer.customerId);
      // `fetchCustomers()` in the original. [PagedListController.reload]
      // rather than `ref.invalidate`, which would rebuild every accumulated
      // page key rather than resetting to the first — and the pages past the
      // deletion are stale anyway, see `reload`.
      await ref.read(customerListProvider(_query!).notifier).reload();
      setState(() => _actionError = null);
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error);
    }
  }

  List<ListColumn<CustomerResponse>> _columns() => [
    ListColumn<CustomerResponse>(
      key: 'name',
      label: 'Name',
      sortable: true,
      render: (context, customer) => RecordLinkButton(
        label: customer.name,
        onPressed: () =>
            context.go(AppRoutes.customerDetails(customer.customerId)),
      ),
    ),
    ListColumn<CustomerResponse>(
      key: 'phone',
      label: 'Phone',
      text: (customer) => customer.phone,
    ),
    ListColumn<CustomerResponse>(
      key: 'address',
      label: 'Address',
      text: (customer) => customer.address,
    ),
    ListColumn<CustomerResponse>(
      key: 'notes',
      label: 'Notes',
      text: (customer) => customer.notes,
    ),
  ];

  /// Builds the provider key from this screen's own state.
  ///
  /// **`limit` and `offset` are deliberately absent.** They used to be here —
  /// `offset: 0` hard-coded, which is why the list could never reach past the
  /// first page. They now belong to [PagedListController], which applies the
  /// page size and advances the offset itself; putting them in the key as well
  /// would make each page its own provider and the screen would have to stitch
  /// N independent results back into one list.
  ///
  /// That this is a plain function of the screen's own state is what makes the
  /// reset work: a changed search term or sort is a different [ListQuery], which
  /// is a different provider, which starts again at offset 0. See
  /// [PagedListController] for why that is the right place for the offset to
  /// live.
  ///
  /// Called from `build` rather than being cached as a getter, because it reads
  /// `selectedOrganizationProvider` — a `ref.watch` inside a getter would be a
  /// dependency registered outside the build that is supposed to own it.
  ListQuery _buildQuery(OrganizationResponse? organization) => ListQuery(
    search: _searchTerm.isEmpty ? null : _searchTerm,
    sortBy: _sortBy,
    sortOrder: _sortOrder,
    // `CustomerList.tsx:32` — only ever non-null for a super-admin, since that
    // is the only case in which a selection exists to scope by.
    organizationId: organization?.organizationId,
  );

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(permissionGateProvider);
    final canManage = gate.has(Permission.manageCustomersOrganization);
    final organization = ref.watch(selectedOrganizationProvider);

    final query = _buildQuery(organization);
    // Assigning during build rather than in an event handler: the search field's
    // debounce and the sort toggle both go through `setState`, and this is the
    // only place that sees the organization selection change without a
    // `setState` of its own.
    _query = query;
    final page = ref.watch(customerListProvider(query));
    final actionError = _actionError;

    return Scaffold(
      body: PagedScrollView(
        onLoadMore: () =>
            ref.read(customerListProvider(_query!).notifier).loadMore(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListScreenHeader(
              title: 'Customers',
              action: canManage
                  ? FilledButton.icon(
                      onPressed: () => context.go(AppRoutes.customerCreate),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Customer'),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            // The debounce from task 4.10 lives with the field, not here —
            // see `DebouncedSearchField` for why every list screen gets the
            // same one rather than its own copy of the timer.
            DebouncedSearchField(
              onChanged: (value) => setState(() => _searchTerm = value),
            ),
            const SizedBox(height: 16),
            if (actionError != null) ...[
              ErrorDisplay.fromException(actionError),
              const SizedBox(height: 16),
            ],
            PagedListBody<CustomerResponse>(
              state: page,
              // The same handler `PagedScrollView` uses for scrolling, so the
              // button and the automatic load cannot drift apart.
              loadMore: () =>
                  ref.read(customerListProvider(query).notifier).loadMore(),
              columns: _columns(),
              idOf: (customer) => customer.customerId,
              emptyMessage: 'No customers found.',
              sortBy: _sortBy,
              sortOrder: _sortOrder,
              onSort: _onSort,
              actions: canManage
                  ? (context, customer) => [
                      ListRowAction(
                        icon: Icons.edit,
                        label: 'Edit',
                        onPressed: () => context.go(
                          AppRoutes.customerEditPath(customer.customerId),
                        ),
                      ),
                      ListRowAction(
                        icon: Icons.delete,
                        label: 'Delete',
                        isDestructive: true,
                        onPressed: () => _confirmDelete(customer),
                      ),
                    ]
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
