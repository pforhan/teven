import 'package:freezed_annotation/freezed_annotation.dart';

part 'common.freezed.dart';
part 'common.g.dart';

/// A page of results. Offset/limit only.
///
/// There is deliberately no page number, cursor, or total-page count: the
/// server exposes none, so deriving one client-side would invent a contract
/// the API does not honour. Mirrors `PaginatedResponse` in
/// `backend/api/.../model/common/PaginatedResponse.kt:5`.
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

/// A simple `{status, message}` acknowledgement.
///
/// Note the server does not actually use this shape for deletes — those
/// return `204 No Content` with an empty body. It is used for the handful of
/// endpoints that answer `success("OK")` / `success("...")`, whose `data` is a
/// bare string rather than this object. Kept for parity with
/// `frontend/src/types/common.ts:7`; task 1.10 decides per-endpoint what a
/// bare-string body actually decodes to.
@freezed
abstract class StatusResponse with _$StatusResponse {
  const factory StatusResponse({
    required String status,
    required String message,
  }) = _StatusResponse;

  factory StatusResponse.fromJson(Map<String, dynamic> json) =>
      _$StatusResponseFromJson(json);
}
