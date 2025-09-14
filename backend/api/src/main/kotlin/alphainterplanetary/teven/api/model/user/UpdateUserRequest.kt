package alphainterplanetary.teven.api.model.user

import kotlinx.serialization.Serializable

@Serializable
data class UpdateUserRequest(
  val email: String? = null,
  val displayName: String? = null,
  val roles: List<String>? = null,
  val staffDetails: UpdateStaffDetails? = null,
  val organizationId: Int? = null,
)

@Serializable
data class UpdateStaffDetails(
  val contactInformation: String? = null,
  val skills: List<String>? = null,
  val phoneNumber: String? = null,
  val dateOfBirth: String? = null, // ISO 8601 date string
)