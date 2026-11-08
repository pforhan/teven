/// Sort direction for a list endpoint.
enum SortOrder {
  asc('asc'),
  desc('desc');

  const SortOrder(this.wireName);

  /// The query-parameter value the server expects.
  final String wireName;
}

/// Query parameters shared by every paginated list endpoint.
///
/// Every list route accepts the same optional set (`limit`, `offset`,
/// `search`, `sortBy`, `sortOrder`, and usually `organizationId`), so this is
/// modelled once rather than as seven near-identical parameter lists.
///
/// **Leaving [limit] null returns every row.** Each DAO does
/// `limit?.let { query.limit(it) }` (`CustomerDao.kt:73`, `EventDao.kt:180`),
/// so omitting the parameter applies no cap at all. The `limit: 0` that comes
/// back in the response is cosmetic and does *not* mean zero rows. This is the
/// trap behind task 1.18.
class ListQuery {
  const ListQuery({
    this.limit,
    this.offset,
    this.search,
    this.sortBy,
    this.sortOrder,
    this.organizationId,
    this.startDate,
    this.endDate,
    this.timezone,
  });

  final int? limit;
  final int? offset;
  final String? search;
  final String? sortBy;
  final SortOrder? sortOrder;
  final int? organizationId;
  final String? startDate;
  final String? endDate;

  /// The IANA zone the date window is interpreted in.
  ///
  /// [startDate] and [endDate] are local dates; the server converts them into an
  /// instant range in this zone. When absent the server falls back to the
  /// caller's organization zone, then UTC. Date-windowed event queries send it so
  /// "the 3rd" means the same day the reader is looking at.
  final String? timezone;

  /// Converts to dio's `queryParameters`, omitting nulls.
  ///
  /// Nulls are dropped rather than sent as empty strings because the server
  /// parses with `toIntOrNull()` and would treat `""` as absent anyway — but
  /// omitting keeps the URL honest.
  Map<String, dynamic> toParams() => {
    if (limit != null) 'limit': limit,
    if (offset != null) 'offset': offset,
    if (search != null && search!.isNotEmpty) 'search': search,
    if (sortBy != null) 'sortBy': sortBy,
    if (sortOrder != null) 'sortOrder': sortOrder!.wireName,
    if (organizationId != null) 'organizationId': organizationId,
    if (startDate != null && startDate!.isNotEmpty) 'startDate': startDate,
    if (endDate != null && endDate!.isNotEmpty) 'endDate': endDate,
    if (timezone != null && timezone!.isNotEmpty) 'timezone': timezone,
  };

  ListQuery copyWith({
    int? limit,
    int? offset,
    String? search,
    String? sortBy,
    SortOrder? sortOrder,
    int? organizationId,
    String? startDate,
    String? endDate,
    String? timezone,
  }) => ListQuery(
    limit: limit ?? this.limit,
    offset: offset ?? this.offset,
    search: search ?? this.search,
    sortBy: sortBy ?? this.sortBy,
    sortOrder: sortOrder ?? this.sortOrder,
    organizationId: organizationId ?? this.organizationId,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    timezone: timezone ?? this.timezone,
  );

  /// Value equality, so a [ListQuery] can key a provider family.
  ///
  /// The list screens rebuild a fresh `ListQuery` on every build, and a
  /// `FutureProvider.family` compares its argument with `==` to decide whether
  /// to refetch. Without this, every unrelated rebuild would re-issue the
  /// request — and with it, a search box would fetch on each keystroke whether
  /// or not the debounce fired.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListQuery &&
          runtimeType == other.runtimeType &&
          limit == other.limit &&
          offset == other.offset &&
          search == other.search &&
          sortBy == other.sortBy &&
          sortOrder == other.sortOrder &&
          organizationId == other.organizationId &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          timezone == other.timezone;

  @override
  int get hashCode => Object.hash(
    limit,
    offset,
    search,
    sortBy,
    sortOrder,
    organizationId,
    startDate,
    endDate,
    timezone,
  );

  @override
  String toString() =>
      'ListQuery(limit: $limit, offset: $offset, search: $search, '
      'sortBy: $sortBy, sortOrder: $sortOrder, organizationId: $organizationId, '
      'timezone: $timezone)';
}
