package alphainterplanetary.teven.api.model.inventory

import alphainterplanetary.teven.api.model.event.EventSummaryResponse
import alphainterplanetary.teven.api.model.organization.OrganizationResponse
import kotlinx.serialization.Serializable

@Serializable
data class InventoryItemResponse(
  val inventoryId: Int,
  val name: String,
  val description: String,
  val quantity: Int,
  val eventCount: Int = 0,
  val events: List<EventSummaryResponse> = emptyList(),
  val organization: OrganizationResponse,
)
