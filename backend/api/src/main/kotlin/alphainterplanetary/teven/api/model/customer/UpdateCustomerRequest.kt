package alphainterplanetary.teven.api.model.customer

import kotlinx.serialization.Serializable

@Serializable
data class UpdateCustomerRequest(
  val name: String? = null,
  val phone: String? = null,
  val address: String? = null,
  val latitude: Double? = null,
  val longitude: Double? = null,
  val formattedAddress: String? = null,
  val notes: String? = null,
  val organizationId: Int? = null,
)
