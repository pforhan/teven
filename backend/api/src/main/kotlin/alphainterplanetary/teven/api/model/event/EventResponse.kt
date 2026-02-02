package alphainterplanetary.teven.api.model.event

import alphainterplanetary.teven.api.model.customer.CustomerResponse
import alphainterplanetary.teven.api.model.organization.OrganizationResponse
import kotlinx.serialization.Serializable

@Serializable
data class EventResponse(
  val eventId: Int,
  val title: String,
  val date: String,
  val time: String,
  val durationMinutes: Int,
  val location: String? = null,
  val description: String? = null,
  val inventoryItems: List<EventInventoryItem>,
  val customer: CustomerResponse? = null,
  val rsvps: List<RsvpStatus>,
  val organization: OrganizationResponse,
  val openInvitation: Boolean = false,
  val numberOfStaffNeeded: Int = 0,
)

@Serializable
data class RsvpStatus(
  val userId: Int,
  val displayName: String,
  val email: String,
  val availability: String, // "available" or "unavailable"
)
