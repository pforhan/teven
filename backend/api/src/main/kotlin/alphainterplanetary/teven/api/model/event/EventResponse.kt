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
  val location: String,
  val description: String,
  val inventoryItems: List<EventInventoryItem>,
  val customer: CustomerResponse,
  val assignedStaffIds: List<Int>,
  val rsvps: List<RsvpStatus>,
  val organization: OrganizationResponse,
)

@Serializable
data class RsvpStatus(
  val userId: Int,
  val displayName: String,
  val email: String,
  val availability: String, // "available" or "unavailable"
)
