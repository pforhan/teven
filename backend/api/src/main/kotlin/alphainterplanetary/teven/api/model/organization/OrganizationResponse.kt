package alphainterplanetary.teven.api.model.organization

import kotlinx.serialization.Serializable

@Serializable
data class OrganizationResponse(
  val organizationId: Int,
  val name: String,
  val contactInformation: String,
)
