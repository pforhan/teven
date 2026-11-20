import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/services/list_query.dart';
import '../../models/inventory.dart';
import '../../models/permissions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/inventory_list.dart';
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

/// The inventory list.
///
/// Search, sort by name or quantity, create, delete, and pagination. The
/// original screen fetched the first 25 rows with no way past the first page;
/// the page size is unchanged, and there is now a way to ask for the next one.
/// See the customer screen for the fuller note.
///
/// The "Used in Events" column shows the server-provided usage count for each
/// item (list responses no longer embed per-event records).
/// The row actions sit in their own column rather than absolutely positioned
/// over the name, which is what the original list did.
/// [ResponsiveListView] owns that decision, as the customer screen does.
class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() =>
      _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  String _searchTerm = '';
  String _sortBy = 'name';
  SortOrder _sortOrder = SortOrder.asc;

  /// The query built during the last build, kept so the delete handler can reach
  /// the same provider the screen is watching. See the customer screen for why
  /// rebuilding it in the handler would be a second copy of the scoping rules.
  ListQuery? _query;

  /// An error from a mutation — a failed delete. The fetch's error lives in the
  /// provider. See the same split on the customer screen.
  ApiException? _actionError;

  void _onSort(String key) {
    // Matches the original list: re-tapping the active column reverses it, and
    // a different column starts ascending.
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

  /// The delete confirmation.
  Future<void> _confirmDelete(InventoryItemResponse item) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete inventory item',
      message:
          'Are you sure you want to delete ${item.name}? This cannot be '
          'undone.',
    );

    if (!confirmed || !mounted) return;

    try {
      await ref
          .read(inventoryServiceProvider)
          .deleteInventoryItem(item.inventoryId);
      // `fetchInventoryItems` in the original — a reload back to the first
      // page rather than `ref.invalidate`, which would rebuild every
      // accumulated page key. See `PagedListController.reload`.
      await ref.read(inventoryListProvider(_query!).notifier).reload();
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
  ListQuery _buildQuery(int? organizationId) => ListQuery(
    search: _searchTerm.isEmpty ? null : _searchTerm,
    sortBy: _sortBy,
    sortOrder: _sortOrder,
    // Scoped by the effective organization: a superadmin in "All
    // Organizations" sees every organization, a superadmin with a selection
    // sees that one, and everyone else sees their own.
    organizationId: organizationId,
  );

  List<ListColumn<InventoryItemResponse>> _columns() => [
    ListColumn<InventoryItemResponse>(
      key: 'name',
      label: 'Name',
      sortable: true,
      render: (context, item) => RecordLinkButton(
        label: item.name,
        onPressed: () =>
            context.go(AppRoutes.inventoryDetailsPath(item.inventoryId)),
      ),
    ),
    ListColumn<InventoryItemResponse>(
      key: 'quantity',
      label: 'Quantity',
      sortable: true,
      // The original list passed the raw number; in a text column it was
      // stringified the same way.
      text: (item) => '${item.quantity}',
    ),
    ListColumn<InventoryItemResponse>(
      key: 'description',
      label: 'Description',
      text: (item) => item.description,
    ),
    ListColumn<InventoryItemResponse>(
      key: 'events',
      label: 'Used in Events',
      render: (context, item) => _UsedInEvents(eventCount: item.eventCount),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(permissionGateProvider);
    final canManage = gate.has(Permission.manageInventoryOrganization);
    final organizationId = ref.watch(queryOrganizationIdProvider);

    final query = _buildQuery(organizationId);
    _query = query;
    final actionError = _actionError;

    Future<void> onRefresh() async {
      if (_query != null) {
        await ref.read(inventoryListProvider(_query!).notifier).reload();
      }
    }

    return Scaffold(
      body: PagedScrollView(
        onLoadMore: () =>
            ref.read(inventoryListProvider(_query!).notifier).loadMore(),
        onRefresh: onRefresh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListScreenHeader(
              title: 'Inventory',
              action: canManage
                  ? FilledButton.icon(
                      onPressed: () => context.go(AppRoutes.inventoryCreate),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Item'),
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
            PagedListSection<InventoryItemResponse>(
              provider: inventoryListProvider(query),
              loadMore: () => ref
                  .read(inventoryListProvider(query).notifier)
                  .loadMore(userInitiated: true),
              onRetry: () => ref.invalidate(inventoryListProvider(query)),
              columns: _columns(),
              idOf: (item) => item.inventoryId,
              emptyMessage: 'No inventory items found.',
              // Only reaches the footer, to word its count. Same test as the one
              // `_buildQuery` uses to decide whether to send `search` at all, so
              // the label cannot claim a filter the request did not apply.
              filtered: _searchTerm.isNotEmpty,
              sortBy: _sortBy,
              sortOrder: _sortOrder,
              onSort: _onSort,
              actions: canManage
                  ? (context, item) => [
                      ListRowAction(
                        icon: Icons.edit,
                        label: 'Edit',
                        onPressed: () => context.go(
                          AppRoutes.inventoryEditPath(item.inventoryId),
                        ),
                      ),
                      ListRowAction(
                        icon: Icons.delete,
                        label: 'Delete',
                        isDestructive: true,
                        onPressed: () => _confirmDelete(item),
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

/// The "Used in Events" cell.
class _UsedInEvents extends StatelessWidget {
  const _UsedInEvents({required this.eventCount});

  final int eventCount;

  @override
  Widget build(BuildContext context) {
    if (eventCount <= 0) {
      return Text(
        'Never used',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.outline),
      );
    }

    return Text(
      'Used in $eventCount ${eventCount == 1 ? 'event' : 'events'}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
