import 'package:freezed_annotation/freezed_annotation.dart';

part 'report.freezed.dart';
part 'report.g.dart';

/// Staff hours over a date range.
///
/// Mirrors `StaffHoursReportResponse` in
/// `backend/api/.../model/report/StaffHoursReportResponse.kt`.
///
/// [displayName] is on the wire but missing from the React type in
/// `frontend/src/types/reports.ts`, so the current report table has no name
/// column. It is included here.
@freezed
abstract class StaffHoursReportResponse with _$StaffHoursReportResponse {
  const factory StaffHoursReportResponse({
    required int userId,
    required String username,
    @Default('') String displayName,
    @Default(0) int totalHoursWorked,
  }) = _StaffHoursReportResponse;

  factory StaffHoursReportResponse.fromJson(Map<String, dynamic> json) =>
      _$StaffHoursReportResponseFromJson(json);
}

@freezed
abstract class StaffHoursReportRequest with _$StaffHoursReportRequest {
  const factory StaffHoursReportRequest({
    required String startDate,
    required String endDate,
  }) = _StaffHoursReportRequest;

  factory StaffHoursReportRequest.fromJson(Map<String, dynamic> json) =>
      _$StaffHoursReportRequestFromJson(json);
}

@freezed
abstract class InventoryUsageReportResponse
    with _$InventoryUsageReportResponse {
  const factory InventoryUsageReportResponse({
    required int inventoryId,
    required String name,
    @Default(0) int usageCount,
  }) = _InventoryUsageReportResponse;

  factory InventoryUsageReportResponse.fromJson(Map<String, dynamic> json) =>
      _$InventoryUsageReportResponseFromJson(json);
}
