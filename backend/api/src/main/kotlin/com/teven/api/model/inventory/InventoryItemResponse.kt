package com.teven.api.model.inventory

import com.teven.api.model.event.EventSummaryResponse
import com.teven.api.model.organization.OrganizationResponse
import kotlinx.serialization.Serializable

@Serializable
data class InventoryItemResponse(
  val inventoryId: Int,
  val name: String,
  val description: String,
  val quantity: Int,
  val events: List<EventSummaryResponse>,
  val organization: OrganizationResponse,
)
