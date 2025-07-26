
package com.teven.api.model.report

import kotlinx.serialization.Serializable

@Serializable
data class StaffHoursReportResponse(
    val userId: Int,
    val username: String,
    val displayName: String,
    val totalHoursWorked: Int
)
