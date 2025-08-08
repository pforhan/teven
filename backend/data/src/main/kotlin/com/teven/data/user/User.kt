package com.teven.data.user

data class User(
  val userId: Int,
  val username: String,
  val email: String,
  val displayName: String,
  val passwordHash: String,
)
