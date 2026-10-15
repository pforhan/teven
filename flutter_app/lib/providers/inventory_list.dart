import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/list_query.dart';
import '../../models/common.dart';
import '../../models/inventory.dart';
import 'paged_list.dart';
import 'service_providers.dart';

/// The inventory list, accumulating a page at a time.
///
/// See [PagedListController] for the shared shape and [customer_list.dart] for
/// the simplest instance of it.
///
/// Note what one of those pages carries. `InventoryDao.getInventoryItems` builds
/// each row through `toInventoryItemResponse`, which selects **every** row of
/// `EventInventory` for that item — so the `events` list is unpaginated on the
/// *list* endpoint too, not only on `GET /api/inventory/{id}`, and it is one
/// extra query per row. The screen caps what it renders; the N+1 is server-side
/// and recorded on task 4.5.
///
/// Pagination makes that per-page cost multiply. It is bounded by what the user
/// actually scrolls through rather than by the table size — the default was
/// always 25 — but it is worth naming, since this is the one endpoint where
/// fetching page 5 is markedly more expensive than fetching page 1.
final inventoryListProvider = AsyncNotifierProvider.autoDispose
    .family<
      PagedInventoryList,
      PagedListState<InventoryItemResponse>,
      ListQuery
    >(PagedInventoryList.new);

class PagedInventoryList extends PagedListController<InventoryItemResponse> {
  PagedInventoryList(super.baseQuery);

  @override
  Future<PaginatedResponse<InventoryItemResponse>> fetchPage(ListQuery query) =>
      ref.watch(inventoryServiceProvider).getAllInventoryItems(query);
}
