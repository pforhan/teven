import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/services/list_query.dart';
import '../../models/organization.dart';
import '../../models/permissions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/organization_list.dart';
import '../../providers/service_providers.dart';
import '../../routing/app_router.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/debounced_search_field.dart';
import '../../widgets/error_display.dart';
import '../../widgets/list_screen_header.dart';
import '../../widgets/paged_list_view.dart';
import '../../widgets/record_link_button.dart';
import '../../widgets/responsive_list_view.dart';

/// The organization list — task 4.6.
///
/// `OrganizationList.tsx` (134 lines). Search, sort, create and delete, over
/// two columns. It is the smallest of the four React lists and the only one
/// that is global rather than organization-scoped: `OrganizationList.tsx:16`
/// gates viewing on `VIEW_ORGANIZATIONS_GLOBAL`, so this screen is reachable
/// only by a super-admin and every row is an organization the caller may not
/// otherwise be scoped to.
///
/// **No organization scoping is applied to its own query, and that is
/// deliberate.** `selectedOrganization` filters every *other* list in the app,
/// but scoping this one to the caller's selected organization would hide every
/// org but one from the list meant to show all of them — and the super-admin
/// selector draws from the same underlying table. The React original passes
/// only `25, 0, search, sortBy, sortOrder` (`OrganizationList.tsx:26-31`), and
/// the same five parameters are all this sends.
class OrganizationListScreen extends ConsumerStatefulWidget {
  const OrganizationListScreen({super.key});

  @override
  ConsumerState<OrganizationListScreen> createState() =>
      _OrganizationListScreenState();
}

class _OrganizationListScreenState
    extends ConsumerState<OrganizationListScreen> {
  String _searchTerm = '';
  String _sortBy = 'name';
  SortOrder _sortOrder = SortOrder.asc;

  /// The query built during the last build, kept so the delete handler can reach
  /// the same provider the screen is watching. See the customer screen for why
  /// rebuilding it in the handler would be a second copy of the scoping rules.
  ListQuery? _query;

  /// An error from a mutation — a failed delete. The fetch's error lives in the
  /// provider.
  ApiException? _actionError;

  /// `OrganizationList.tsx:67-75`: re-tapping the active column reverses it,
  /// and a different column starts ascending.
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

  /// The delete confirmation. `OrganizationList.tsx:51`.
  Future<void> _confirmDelete(OrganizationResponse organization) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete organization',
      message:
          'Are you sure you want to delete ${organization.name}? This cannot '
          'be undone.',
    );

    if (!confirmed || !mounted) return;

    try {
      await ref
          .read(organizationServiceProvider)
          .deleteOrganization(organization.organizationId);
      // `fetchOrganizations()` in the original — a reload back to the first
      // page. See `PagedListController.reload`.
      await ref.read(organizationPageProvider(_query!).notifier).reload();
      setState(() => _actionError = null);
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error);
    }
  }

  /// Builds the provider key from this screen's own state.
  ///
  /// **`limit` and `offset` are deliberately absent** — they belong to
  /// `PagedListController`, which applies the page size and advances the offset
  /// itself. See the customer screen for why.
  ///
  /// **And note what is missing from this one: `organizationId`.** Every other
  /// list screen scopes by the super-admin's selection, and copying that line
  /// here — the obvious way to make this screen match its three siblings — would
  /// hide every organization but one from the list whose entire job is to show
  /// all of them. See the class doc comment. The React original passes only
  /// `25, 0, search, sortBy, sortOrder` (`OrganizationList.tsx:26-31`), and so
  /// does this.
  ListQuery _buildQuery() => ListQuery(
    search: _searchTerm.isEmpty ? null : _searchTerm,
    sortBy: _sortBy,
    sortOrder: _sortOrder,
  );

  List<ListColumn<OrganizationResponse>> _columns() => [
    ListColumn<OrganizationResponse>(
      key: 'name',
      label: 'Name',
      sortable: true,
      render: (context, organization) => RecordLinkButton(
        label: organization.name,
        onPressed: () => context.go(
          AppRoutes.organizationDetails(organization.organizationId),
        ),
      ),
    ),
    ListColumn<OrganizationResponse>(
      key: 'contactInformation',
      label: 'Contact Information',
      text: (organization) => organization.contactInformation,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(permissionGateProvider);
    final canManage = gate.has(Permission.manageOrganizationsGlobal);

    final query = _buildQuery();
    _query = query;
    final page = ref.watch(organizationPageProvider(query));
    final actionError = _actionError;

    return Scaffold(
      body: PagedScrollView(
        onLoadMore: () =>
            ref.read(organizationPageProvider(_query!).notifier).loadMore(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListScreenHeader(
              title: 'Organizations',
              action: canManage
                  ? FilledButton.icon(
                      onPressed: () => context.go(AppRoutes.organizationCreate),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Organization'),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            DebouncedSearchField(
              onChanged: (value) => setState(() => _searchTerm = value),
            ),
            const SizedBox(height: 16),
            if (actionError != null) ...[
              ErrorDisplay.fromException(actionError),
              const SizedBox(height: 16),
            ],
            PagedListBody<OrganizationResponse>(
              state: page,
              loadMore: () =>
                  ref.read(organizationPageProvider(query).notifier).loadMore(),
              columns: _columns(),
              idOf: (organization) => organization.organizationId,
              emptyMessage: 'No organizations found.',
              sortBy: _sortBy,
              sortOrder: _sortOrder,
              onSort: _onSort,
              actions: canManage
                  ? (context, organization) => [
                      ListRowAction(
                        icon: Icons.edit,
                        label: 'Edit',
                        onPressed: () => context.go(
                          AppRoutes.organizationEditPath(
                            organization.organizationId,
                          ),
                        ),
                      ),
                      ListRowAction(
                        icon: Icons.delete,
                        label: 'Delete',
                        isDestructive: true,
                        onPressed: () => _confirmDelete(organization),
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
