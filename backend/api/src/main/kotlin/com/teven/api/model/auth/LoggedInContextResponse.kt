package com.teven.api.model.auth

import com.teven.api.model.organization.OrganizationDetails
import com.teven.api.model.user.UserResponse
import kotlinx.serialization.Serializable

@Serializable
data class LoggedInContextResponse(
  val user: UserResponse,
  val organization: OrganizationDetails,
  val permissions: List<String>, // List of permissions for the user in current context
)
