import 'package:freezed_annotation/freezed_annotation.dart';

part 'common.freezed.dart';
part 'common.g.dart';

/// A page of results. Offset/limit only.
///
/// There is deliberately no page number, cursor, or total-page count: the
/// server exposes none, so deriving one client-side would invent a contract
/// the API does not honour. Mirrors `PaginatedResponse` in
/// `backend/api/.../model/common/PaginatedResponse.kt`.
@Freezed(genericArgumentFactories: true)
abstract class PaginatedResponse<T> with _$PaginatedResponse<T> {
  const factory PaginatedResponse({
    required List<T> items,
    @Default(0) int total,
    @Default(0) int offset,
    @Default(0) int limit,
  }) = _PaginatedResponse<T>;

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) decodeItem,
  ) => _$PaginatedResponseFromJson(json, decodeItem);
}
