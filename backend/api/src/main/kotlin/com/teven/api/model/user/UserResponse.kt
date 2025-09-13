package com.teven.api.model.user

import com.teven.api.model.auth.StaffDetails
import com.teven.api.model.organization.Organization
import kotlinx.serialization.Serializable

@Serializable
data class UserResponse(
  val userId: Int,
  val username: String,
  val email: String,
  val displayName: String,
  val roles: List<String>,
  val staffDetails: StaffDetails? = null,
  val organization: Organization,
)
