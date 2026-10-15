import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/list_query.dart';
import '../../models/common.dart';
import '../../models/inventory.dart';
import 'service_providers.dart';

/// One page of inventory items, keyed by the query that produced it.
///
/// The same shape and the same reasoning as `customerListProvider`: the screen
/// owns every input, and changing one produces a different [ListQuery] key.
/// See that provider for why the argument has value equality.
///
/// Note what one of those pages carries. `InventoryDao.getInventoryItems`
/// builds each row through `toInventoryItemResponse`, which selects **every**
/// row of `EventInventory` for that item — so the `events` list is unpaginated
/// on the *list* endpoint too, not only on `GET /api/inventory/{id}`, and it is
/// one extra query per row. The screen caps what it renders; the N+1 is
/// server-side and recorded on task 4.5.
final inventoryListProvider = FutureProvider.autoDispose
    .family<PaginatedResponse<InventoryItemResponse>, ListQuery>(
      (ref, query) =>
          ref.watch(inventoryServiceProvider).getAllInventoryItems(query),
    );
