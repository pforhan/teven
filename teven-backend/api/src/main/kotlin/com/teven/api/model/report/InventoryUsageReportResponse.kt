
package com.teven.api.model.report

import kotlinx.serialization.Serializable

@Serializable
data class InventoryUsageReportResponse(
    val inventoryId: Int,
    val name: String,
    val usageCount: Int
)
