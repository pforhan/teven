package com.teven.api.model.auth

import com.teven.api.model.user.UserResponse
import kotlinx.serialization.Serializable

@Serializable
data class LoginResponse(
  val token: String,
  val user: UserResponse,
)
