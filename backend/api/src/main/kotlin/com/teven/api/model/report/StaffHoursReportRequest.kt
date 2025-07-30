package com.teven.api.model.report

import kotlinx.serialization.Serializable

@Serializable
data class StaffHoursReportRequest(
  val startDate: String, // ISO 8601 date string
  val endDate: String,  // ISO 8601 date string
)
