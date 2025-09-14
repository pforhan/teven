package alphainterplanetary.teven.api.model.auth

import kotlinx.serialization.Serializable

@Serializable
data class LoginRequest(
  val username: String,
  val password: String,
)
