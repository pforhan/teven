package com.teven.api.model.user

import kotlinx.serialization.Serializable

// TODO for users with appropriate permissions, need to allow a role specification
@Serializable
data class CreateUserRequest(
  val username: String,
  val password: String,
  val email: String,
  val displayName: String,
  val roles: List<String> = emptyList(),
)