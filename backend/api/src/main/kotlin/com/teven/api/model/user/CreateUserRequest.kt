package com.teven.api.model.user

import kotlinx.serialization.Serializable

@Serializable
data class CreateUserRequest(
  val username: String,
  val password: String,
  val email: String,
  val displayName: String,
  // Ignored if the caller is not a superadmin.
  val roles: List<String> = emptyList(),
  // Ignored if the caller is not a superadmin.
  val organizationId: Int,
)