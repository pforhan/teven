package alphainterplanetary.teven.api.model.organization

import kotlinx.serialization.Serializable

@Serializable
data class UpdateOrganizationRequest(
  val name: String? = null,
  val contactInformation: String? = null,
)
