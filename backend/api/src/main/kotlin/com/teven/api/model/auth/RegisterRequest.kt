package com.teven.api.model.auth

import kotlinx.serialization.Serializable

@Serializable
data class RegisterRequest(
  val username: String,
  val password: String,
  val email: String,
  val displayName: String,
  val role: String, // e.g., "organizer", "staff"
)
