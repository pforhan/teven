package alphainterplanetary.teven.api.model.user

import alphainterplanetary.teven.api.model.auth.StaffDetails
import alphainterplanetary.teven.api.model.organization.OrganizationResponse
import kotlinx.serialization.Serializable

@Serializable
data class UserResponse(
  val userId: Int,
  val username: String,
  val email: String,
  val displayName: String,
  val roles: List<String>,
  val staffDetails: StaffDetails? = null,
  val organization: OrganizationResponse,
)
