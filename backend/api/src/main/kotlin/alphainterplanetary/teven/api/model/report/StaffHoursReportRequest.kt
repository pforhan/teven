package alphainterplanetary.teven.api.model.report

import kotlinx.serialization.Serializable

@Serializable
data class StaffHoursReportRequest(
  val organizationId: Int, // Required; callers without VIEW_REPORTS_GLOBAL may only request their own org
  val startDate: String, // ISO 8601 date string (local date)
  val endDate: String, // ISO 8601 date string (local date)
  val timezone: String, // IANA zone naming the window; dates are day boundaries in this zone
)
