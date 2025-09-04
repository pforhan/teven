package com.teven.api.model.user

import kotlinx.serialization.Serializable

// TODO should be able to specify an organization
@Serializable
data class CreateUserRequest(
  val username: String,
  val password: String,
  val email: String,
  val displayName: String,
  val roles: List<String> = emptyList(),
)