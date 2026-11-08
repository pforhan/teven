package alphainterplanetary.teven.api.model.event

import kotlinx.serialization.Serializable

@Serializable
data class CreateEventRequest(
  val title: String,
  val durationMinutes: Int,
  val inventoryItems: List<EventInventoryItem>,
  val staffInvites: StaffInviteDetails,
  val organizationId: Int,
  val startsAt: String,
  val timezone: String,
  val location: String? = null,
  val latitude: Double? = null,
  val longitude: Double? = null,
  val formattedAddress: String? = null,
  val description: String? = null,
  val customerId: Int? = null,
)

@Serializable
data class StaffInviteDetails(
  val specificStaffIds: List<Int>? = null, // Optional: list of specific staff to invite
  val openInvitation: Boolean = false, // True if invitation is open to any staff
  val numberOfStaffNeeded: Int, // Required: number of staff slots for the event
)
