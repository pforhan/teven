import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/list_query.dart';
import '../../models/common.dart';
import '../../models/customer.dart';
import 'paged_list.dart';
import 'service_providers.dart';

/// The customer list, accumulating a page at a time.
///
/// The shape and the reasoning are shared with the inventory, organization and
/// user screens — see [PagedListController]. This file is the customer half of
/// that: which service to call, and nothing else.
final customerListProvider = AsyncNotifierProvider.autoDispose
    .family<PagedCustomerList, PagedListState<CustomerResponse>, ListQuery>(
      PagedCustomerList.new,
      retry: noRetry,
    );

class PagedCustomerList extends PagedListController<CustomerResponse> {
  PagedCustomerList(super.baseQuery);

  @override
  Future<PaginatedResponse<CustomerResponse>> fetchPage(ListQuery query) =>
      ref.watch(customerServiceProvider).getAllCustomers(query);
}
