import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';

import '../../core/services/list_query.dart';
import '../../models/customer.dart';
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
import '../../widgets/record_link_button.dart';
import '../../widgets/responsive_list_view.dart';

/// The customer list.
///
/// `CustomerList.tsx` (134 lines). Search, sort, create and delete — there is
/// no pagination control in the React original, which fetches a fixed first
/// page of 25 and offers no way to reach the rest. That behaviour is kept
/// rather than improved here, so the list still shows 25 rows at most; task 4.9
/// is where paging becomes real.
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
  /// `CustomerList.tsx:27` — `getAllCustomers(25, 0, ...)`.
  static const int _pageLimit = 25;

  String _searchTerm = '';
  String _sortBy = 'name';
  SortOrder _sortOrder = SortOrder.asc;

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
      // `fetchCustomers()` in the original. Invalidation rather than a
      // direct refetch so the screen does not have to hold the result to
      // re-request it.
      ref.invalidate(customerListProvider);
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

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(permissionGateProvider);
    final canManage = gate.has(Permission.manageCustomersOrganization);
    final organization = ref.watch(selectedOrganizationProvider);

    final query = ListQuery(
      limit: _pageLimit,
      offset: 0,
      search: _searchTerm.isEmpty ? null : _searchTerm,
      sortBy: _sortBy,
      sortOrder: _sortOrder,
      // `CustomerList.tsx:32` — only ever non-null for a super-admin, since that
      // is the only case in which a selection exists to scope by.
      organizationId: organization?.organizationId,
    );

    final page = ref.watch(customerListProvider(query));
    final actionError = _actionError;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
            page.when(
              // A new query — a search term, a re-sort — starts from scratch,
              // so the whole card becomes a spinner. The React original kept
              // the previous rows up until the response arrived (it only
              // called `setCustomers` on success), so this flashes where that
              // did not. Riverpod can retain the last value across family keys
              // with a keep-alive link provider; that is more machinery than a
              // list with 25 rows in it justifies, and it is recorded here
              // rather than forgotten.
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorDisplay.fromException(
                error is ApiException ? error : ApiRequestException('$error'),
              ),
              data: (page) => ResponsiveListView<CustomerResponse>(
                data: page.items,
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
            ),
          ],
        ),
      ),
    );
  }
}
