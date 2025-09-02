package com.teven.core.security

data class JwtConfig(
  val secret: String,
  val issuer: String,
  val audience: String,
  val expirationTimeMillis: Long,
)