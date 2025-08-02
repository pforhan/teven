package com.teven.api.model.user

import com.teven.api.model.auth.StaffDetails
import kotlinx.serialization.Serializable

@Serializable
data class UserResponse(
  val userId: Int,
  val username: String,
  val email: String,
  val displayName: String,
  val role: String,
  val passwordHash: String,
  val staffDetails: StaffDetails? = null,
)
