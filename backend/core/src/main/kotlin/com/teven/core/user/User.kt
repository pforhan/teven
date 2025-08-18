package com.teven.core.user

import com.teven.api.model.user.UserResponse

data class User(
  val userId: Int,
  val username: String,
  val email: String,
  val displayName: String,
  val passwordHash: String,
)
