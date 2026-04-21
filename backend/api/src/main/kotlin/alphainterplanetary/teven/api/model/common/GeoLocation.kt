package alphainterplanetary.teven.api.model.common

import kotlinx.serialization.Serializable

@Serializable
data class GeoLocation(
  val latitude: Double,
  val longitude: Double,
  val formattedAddress: String? = null,
)
