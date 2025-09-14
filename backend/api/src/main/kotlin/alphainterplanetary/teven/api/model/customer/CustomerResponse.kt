package alphainterplanetary.teven.api.model.customer

import alphainterplanetary.teven.api.model.organization.OrganizationResponse
import kotlinx.serialization.Serializable

@Serializable
data class CustomerResponse(
  val customerId: Int,
  val name: String,
  val phone: String,
  val address: String,
  val notes: String,
  val organization: OrganizationResponse,
)
