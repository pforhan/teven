package alphainterplanetary.teven.api.model.event

import kotlinx.serialization.Serializable

@Serializable
data class RsvpRequest(
  val availability: String, // accepted | declined | tentative | needs_action
)
