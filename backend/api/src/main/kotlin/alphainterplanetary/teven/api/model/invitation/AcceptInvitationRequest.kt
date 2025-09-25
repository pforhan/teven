package alphainterplanetary.teven.api.model.invitation

import alphainterplanetary.teven.api.model.user.CreateUserRequest
import kotlinx.serialization.Serializable

@Serializable
data class AcceptInvitationRequest(
  val token: String,
  val username: String,
  val password: String,
  val email: String,
  val displayName: String,
) {
  fun toCreateUserRequest(organizationId: Int) = CreateUserRequest(
    username = username,
    password = password,
    email = email,
    displayName = displayName,
    organizationId = organizationId,
    roles = emptyList() // Roles are assigned from invitation, not accept request
  )
}
