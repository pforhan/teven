package com.teven.api.model.event

import kotlinx.serialization.Serializable

@Serializable
data class EventSummaryResponse(
  val eventId: Int,
  val title: String,
  val quantity: Int,
)
