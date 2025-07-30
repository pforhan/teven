package com.teven.core.config

data class JwtConfig(
  val secret: String,
  val issuer: String,
  val audience: String,
)
