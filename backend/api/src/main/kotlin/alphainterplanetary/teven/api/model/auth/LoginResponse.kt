package alphainterplanetary.teven.api.model.auth

import alphainterplanetary.teven.api.model.user.UserResponse
import kotlinx.serialization.Serializable

@Serializable
data class LoginResponse(
  val token: String,
  val user: UserResponse,
)
