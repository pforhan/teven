package com.teven.api.model.event

import kotlinx.serialization.Serializable

@Serializable
data class CreateEventRequest(
  val title: String,
  val date: String, // ISO 8601 date string (e.g., "YYYY-MM-DD")
  val time: String, // ISO 8601 time string (e.g., "HH:MM:SS")
  val location: String,
  val description: String,
  val inventoryIds: List<Int>,
  val customerId: Int, // Single customer ID
  val staffInvites: StaffInviteDetails, // Details for staff invitation
  val organizationId: Int,
)

@Serializable
data class StaffInviteDetails(
  val specificStaffIds: List<Int>? = null, // Optional: list of specific staff to invite
  val openInvitation: Boolean = false, // True if invitation is open to any staff
  val numberOfStaffNeeded: Int, // Required: number of staff slots for the event
)
