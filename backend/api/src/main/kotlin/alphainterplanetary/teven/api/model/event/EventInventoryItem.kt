package alphainterplanetary.teven.api.model.event

import kotlinx.serialization.Serializable

@Serializable
data class EventInventoryItem(
  val inventoryId: Int,
  val quantity: Int,
)