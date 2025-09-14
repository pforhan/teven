package alphainterplanetary.teven.api.model.event

import kotlinx.serialization.Serializable

@Serializable
data class UpdateEventRequest(
  val title: String? = null,
  val date: String? = null,
  val time: String? = null,
  val location: String? = null,
  val description: String? = null,
  val inventoryItems: List<EventInventoryItem>? = null,
  val customerId: Int? = null,
  val staffInvites: StaffInviteDetails? = null,
  val organizationId: Int? = null,
)
