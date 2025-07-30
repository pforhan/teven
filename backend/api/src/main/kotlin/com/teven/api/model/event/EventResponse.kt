package com.teven.api.model.event

import kotlinx.serialization.Serializable

@Serializable
data class EventResponse(
  val eventId: Int,
  val title: String,
  val date: String,
  val time: String,
  val location: String,
  val description: String,
  val inventoryIds: List<Int>,
  val customerId: Int,
  val assignedStaffIds: List<Int>,
  val rsvps: List<RsvpStatus>,
)

@Serializable
data class RsvpStatus(
  val userId: Int,
  val availability: String, // "available" or "unavailable"
)
