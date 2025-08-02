package com.teven.api.model.auth

import com.teven.api.model.organization.OrganizationDetails
import com.teven.api.model.user.UserResponse
import kotlinx.serialization.Serializable

@Serializable
data class UserContextResponse(
  val user: UserResponse,
  val organization: OrganizationDetails?, // Nullable if user not part of org
  val permissions: List<String>, // List of permissions for the user in current context
)
