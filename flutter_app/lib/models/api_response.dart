import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_response.freezed.dart';
part 'api_response.g.dart';

/// Error payload carried inside a failed [ApiResponse].
///
/// Mirrors `ApiError` in
/// `backend/api/.../model/common/ApiResponse.kt:19`.
@freezed
abstract class ApiError with _$ApiError {
  const factory ApiError({required String message, String? details}) =
      _ApiError;

  factory ApiError.fromJson(Map<String, dynamic> json) =>
      _$ApiErrorFromJson(json);
}

/// The server's response envelope, with `data` typed.
///
/// Every Teven endpoint answers with `{success, data, error}`
/// (`backend/api/.../model/common/ApiResponse.kt:8`). [data] is nullable
/// because the server's `failure()` helper does **not** omit it — it sets
/// `data = Unit`, which serialises to `{}`. So a failed response carries a
/// non-null `data` that is `{}`, not `null`. Callers must therefore never
/// read `data` without first checking [success] / [error].
///
/// [fromJson] takes a [decode] callback rather than relying on generated
/// deserialization, precisely so that this is safe: `decode` is invoked
/// **only** when `success` is true. A generated `fromJson` would try to decode
/// `{}` into `T` on every failure and throw, destroying the very error
/// message the caller needs. Task 1.10 leans on this when mapping a response
/// to `List<EventResponse>` and friends.
@freezed
abstract class ApiResponse<T> with _$ApiResponse<T> {
  const factory ApiResponse({required bool success, T? data, ApiError? error}) =
      _ApiResponse<T>;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) decode,
  ) {
    final errorJson = json['error'];
    final ApiError? error = errorJson is Map<String, dynamic>
        ? ApiError.fromJson(errorJson)
        : null;

    final success = json['success'] as bool? ?? false;
    if (!success) {
      return ApiResponse<T>(success: false, error: error);
    }

    final rawData = json['data'];
    return ApiResponse<T>(
      success: true,
      data: rawData == null ? null : decode(rawData),
    );
  }
}
