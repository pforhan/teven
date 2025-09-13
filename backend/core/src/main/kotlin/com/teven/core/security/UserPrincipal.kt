package com.teven.core.security

data class UserPrincipal(
  val userId: Int,
  val organizationId: Int,
  val permissions: Set<Permission>,
)
