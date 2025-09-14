package alphainterplanetary.teven.api.model.event

import kotlinx.serialization.Serializable

@Serializable
data class RsvpRequest(
  val availability: String, // "available" or "unavailable"
)
