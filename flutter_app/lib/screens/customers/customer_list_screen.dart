import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/services/list_query.dart';
import '../../models/customer.dart';
import '../../models/permissions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/customer_list.dart';
import '../../providers/effective_organization_scope.dart';
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
/// Search, sort, create, deactivate/restore, and pagination. Follows the user
/// list's status-filter pattern for deactivated customers.
class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  String _searchTerm = '';
  String _sortBy = 'name';
  SortOrder _sortOrder = SortOrder.asc;
  String _statusFilter = 'active';

  ListQuery? _query;
  ApiException? _actionError;

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

  Future<void> _confirmDeactivate(CustomerResponse customer) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Deactivate customer',
      message:
          'Are you sure you want to deactivate ${customer.name}? Historical '
          'event associations will be retained and the customer can be restored later.',
      confirmLabel: 'Deactivate',
    );

    if (!confirmed || !mounted) return;

    try {
      await ref
          .read(customerServiceProvider)
          .deleteCustomer(customer.customerId);
      await ref.read(customerListProvider(_query!).notifier).reload();
      setState(() => _actionError = null);
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error);
    }
  }

  Future<void> _restoreCustomer(CustomerResponse customer) async {
    try {
      await ref
          .read(customerServiceProvider)
          .restoreCustomer(customer.customerId);
      await ref.read(customerListProvider(_query!).notifier).reload();
      setState(() => _actionError = null);
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error);
    }
  }

  List<ListColumn<CustomerResponse>> _columns({required bool showStatus}) => [
    ListColumn<CustomerResponse>(
      key: 'name',
      label: 'Name',
      sortable: true,
      render: (context, customer) => RecordLinkButton(
        label: customer.name,
        onPressed: () =>
            context.go(AppRoutes.customerDetailsPath(customer.customerId)),
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
    if (showStatus)
      ListColumn<CustomerResponse>(
        key: 'status',
        label: 'Status',
        text: (customer) =>
            customer.deletedAt == null ? 'Active' : 'Deactivated',
      ),
  ];

  ListQuery _buildQuery(
    int? organizationId, {
    required bool canAccessDeactivated,
  }) => ListQuery(
    search: _searchTerm.isEmpty ? null : _searchTerm,
    sortBy: _sortBy,
    sortOrder: _sortOrder,
    organizationId: organizationId,
    status: canAccessDeactivated ? _statusFilter : null,
  );

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(permissionGateProvider);
    final canManage = gate.hasAny([
      Permission.manageCustomersOrganization,
      Permission.manageCustomersGlobal,
    ]);
    final canViewGlobal = gate.has(Permission.viewCustomersGlobal);
    final canAccessDeactivated = canViewGlobal || canManage;
    final organizationId = ref.watch(queryOrganizationIdProvider);

    final query = _buildQuery(
      organizationId,
      canAccessDeactivated: canAccessDeactivated,
    );
    _query = query;
    final actionError = _actionError;

    Future<void> onRefresh() async {
      if (_query != null) {
        await ref.read(customerListProvider(_query!).notifier).reload();
      }
    }

    return Scaffold(
      body: PagedScrollView(
        onLoadMore: () =>
            ref.read(customerListProvider(_query!).notifier).loadMore(),
        onRefresh: onRefresh,
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
            if (canAccessDeactivated) ...[
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'active', label: Text('Active')),
                  ButtonSegment(
                    value: 'deactivated',
                    label: Text('Deactivated'),
                  ),
                  ButtonSegment(value: 'all', label: Text('All')),
                ],
                selected: {_statusFilter},
                onSelectionChanged: (selection) {
                  setState(() => _statusFilter = selection.first);
                },
              ),
              const SizedBox(height: 16),
            ],
            DebouncedSearchField(
              onChanged: (value) => setState(() => _searchTerm = value),
            ),
            const SizedBox(height: 16),
            if (actionError != null) ...[
              ErrorDisplay.fromException(actionError),
              const SizedBox(height: 16),
            ],
            PagedListSection<CustomerResponse>(
              provider: customerListProvider(query),
              loadMore: () =>
                  ref.read(customerListProvider(query).notifier).loadMore(),
              columns: _columns(showStatus: canAccessDeactivated),
              idOf: (customer) => customer.customerId,
              emptyMessage: 'No customers found.',
              filtered: _searchTerm.isNotEmpty,
              sortBy: _sortBy,
              sortOrder: _sortOrder,
              onSort: _onSort,
              actions: canManage
                  ? (context, customer) {
                      final isDeactivated = customer.deletedAt != null;
                      return [
                        if (!isDeactivated)
                          ListRowAction(
                            icon: Icons.edit,
                            label: 'Edit',
                            onPressed: () => context.go(
                              AppRoutes.customerEditPath(customer.customerId),
                            ),
                          ),
                        if (!isDeactivated)
                          ListRowAction(
                            icon: Icons.person_off,
                            label: 'Deactivate',
                            isDestructive: true,
                            onPressed: () => _confirmDeactivate(customer),
                          ),
                        if (isDeactivated)
                          ListRowAction(
                            icon: Icons.restore,
                            label: 'Restore',
                            onPressed: () => _restoreCustomer(customer),
                          ),
                      ];
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
