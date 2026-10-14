import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/list_query.dart';
import '../../models/common.dart';
import '../../models/customer.dart';
import 'service_providers.dart';

/// One page of customers, keyed by the query that produced it.
///
/// A `FutureProvider.family` rather than an `AsyncNotifier` because the screen
/// owns every input — the search text, the sort column, the selected
/// organization — and there is nothing to hold that the query does not already
/// carry. Changing an input produces a different key, Riverpod fetches, and
/// the previous result stays on screen until the new one arrives, which is
/// what `useEffect` + `setCustomers` did in the React original.
///
/// [ListQuery] has value equality for exactly this reason; without it every
/// rebuild would be a new key and every keystroke a request.
final customerListProvider = FutureProvider.autoDispose
    .family<PaginatedResponse<CustomerResponse>, ListQuery>(
      (ref, query) => ref.watch(customerServiceProvider).getAllCustomers(query),
    );
