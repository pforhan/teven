package alphainterplanetary.teven.api.model.user

import kotlinx.serialization.Serializable

@Serializable
data class MinimalUserResponse(
  val userId: Int,
  val displayName: String,
  val email: String,
)
