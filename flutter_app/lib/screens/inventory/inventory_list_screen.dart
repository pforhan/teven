import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/services/list_query.dart';
import '../../models/inventory.dart';
import '../../models/permissions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/inventory_list.dart';
import '../../providers/organization_controller.dart';
import '../../providers/service_providers.dart';
import '../../routing/app_router.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/debounced_search_field.dart';
import '../../widgets/error_display.dart';
import '../../widgets/list_screen_header.dart';
import '../../widgets/record_link_button.dart';
import '../../widgets/responsive_list_view.dart';

/// The inventory list.
///
/// `InventoryList.tsx` (144 lines). Search, sort by name or quantity, create,
/// and delete. Like the customer list there is no pagination control — the
/// React original fetches `25, 0` and offers no way past the first page, and
/// task 4.9 is where paging becomes real.
///
/// Two things here are not a transcription:
///
/// - **The "Used in Events" column is capped.** `InventoryDao` embeds every
///   event that has ever drawn on an item, unpaginated, on the list endpoint as
///   well as on the single-item one. A popular item can have hundreds of rows
///   of `ID: 12 (Qty: 4)` in one cell, which is a table row tall enough to
///   swallow the rest of the screen. [maxEventsShown] bounds it and the
///   remainder becomes a count.
/// - **The row actions sit in their own column** rather than absolutely
///   positioned over the name, which is what `InventoryList.tsx:77-89` does.
///   [ResponsiveListView] owns that decision; the customer screen made the same
///   call in task 4.4.
class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() =>
      _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  /// `InventoryList.tsx:27` — `getAllInventoryItems(25, 0, ...)`.
  static const int _pageLimit = 25;

  String _searchTerm = '';
  String _sortBy = 'name';
  SortOrder _sortOrder = SortOrder.asc;

  /// An error from a mutation — a failed delete. The fetch's error lives in the
  /// provider. See the same split on the customer screen.
  ApiException? _actionError;

  void _onSort(String key) {
    // `InventoryList.tsx:50-57`: re-tapping the active column reverses it, and
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

  /// The delete confirmation. `InventoryList.tsx:60`.
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
      // `fetchInventoryItems()` in the original — an invalidation, so the
      // screen does not have to hold the result to re-request it.
      ref.invalidate(inventoryListProvider);
      setState(() => _actionError = null);
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error);
    }
  }

  List<ListColumn<InventoryItemResponse>> _columns() => [
    ListColumn<InventoryItemResponse>(
      key: 'name',
      label: 'Name',
      sortable: true,
      render: (context, item) => RecordLinkButton(
        label: item.name,
        onPressed: () =>
            context.go(AppRoutes.inventoryDetails(item.inventoryId)),
      ),
    ),
    ListColumn<InventoryItemResponse>(
      key: 'quantity',
      label: 'Quantity',
      sortable: true,
      // `InventoryList.tsx:92` passes the raw number; it is a `Text` column, so
      // the original stringified it the same way.
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
      render: (context, item) => _UsedInEvents(events: item.events),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(permissionGateProvider);
    final canManage = gate.has(Permission.manageInventoryOrganization);
    final organization = ref.watch(selectedOrganizationProvider);

    final query = ListQuery(
      limit: _pageLimit,
      offset: 0,
      search: _searchTerm.isEmpty ? null : _searchTerm,
      sortBy: _sortBy,
      sortOrder: _sortOrder,
      // `InventoryList.tsx:32` — only ever non-null for a super-admin, since
      // that is the only case in which a selection exists to scope by.
      organizationId: organization?.organizationId,
    );

    final page = ref.watch(inventoryListProvider(query));
    final actionError = _actionError;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
            page.when(
              // As on the customer list, a new query drops the whole card to a
              // spinner rather than leaving the previous rows up — see task 4.14
              // for the three ways to stop that, none taken yet.
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorDisplay.fromException(
                error is ApiException ? error : ApiRequestException('$error'),
              ),
              data: (page) => ResponsiveListView<InventoryItemResponse>(
                data: page.items,
                columns: _columns(),
                idOf: (item) => item.inventoryId,
                emptyMessage: 'No inventory items found.',
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
            ),
          ],
        ),
      ),
    );
  }
}

/// How many of an item's events a row names before it counts the rest.
const int maxEventsShown = 3;

/// The "Used in Events" cell.
///
/// `InventoryList.tsx:97-103` rendered every entry, which the server has no
/// bound on — see [InventoryListScreen]. Shown as a bulleted list in a table
/// cell and as a labelled block in a card, because the cell renders in both.
class _UsedInEvents extends StatelessWidget {
  const _UsedInEvents({required this.events});

  final List<EventSummaryResponse> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Text(
        'Never used',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.outline),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final shown = events.take(maxEventsShown);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The React original's `<li>` text, verbatim in substance. `title` is
        // never rendered because the server does not populate it:
        // `InventoryDao` builds each `EventSummaryResponse` with `""`.
        for (final event in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              'ID: ${event.eventId} (Qty: ${event.quantity})',
              style: textTheme.bodySmall,
            ),
          ),
        if (events.length > maxEventsShown)
          Text(
            '+${events.length - maxEventsShown} more',
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
      ],
    );
  }
}
