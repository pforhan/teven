package alphainterplanetary.teven.api.model.auth

import kotlinx.serialization.Serializable

@Serializable
data class StaffDetails(
  val contactInformation: String,
  val skills: List<String>,
  val hoursWorked: Int,
  val phoneNumber: String,
  val dateOfBirth: String, // ISO 8601 date string
)
