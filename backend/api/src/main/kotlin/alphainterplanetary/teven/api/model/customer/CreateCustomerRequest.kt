package alphainterplanetary.teven.api.model.customer

import kotlinx.serialization.Serializable

@Serializable
data class CreateCustomerRequest(
  val name: String,
  val phone: String,
  val address: String,
  val latitude: Double? = null,
  val longitude: Double? = null,
  val formattedAddress: String? = null,
  val notes: String,
  val organizationId: Int? = null,
)
