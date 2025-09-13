package com.teven.api.model.auth

import com.teven.api.model.organization.OrganizationResponse
import com.teven.api.model.user.UserResponse
import kotlinx.serialization.Serializable

@Serializable
data class LoggedInContextResponse(
  val user: UserResponse,
  val permissions: List<String>, // List of permissions for the user in current context
)
