package com.teven.api.model.event

import com.teven.api.model.customer.CustomerResponse
import com.teven.api.model.organization.OrganizationResponse
import kotlinx.serialization.Serializable

@Serializable
data class EventResponse(
  val eventId: Int,
  val title: String,
  val date: String,
  val time: String,
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
  val availability: String, // "available" or "unavailable"
)
