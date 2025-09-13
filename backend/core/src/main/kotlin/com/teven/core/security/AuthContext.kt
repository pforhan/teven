package com.teven.core.security

// TODO merge UserPrincipal and AuthContext
data class AuthContext(
  val userId: Int,
  val organizationId: Int,
  val permissions: Set<Permission>,
) {
  fun hasPermission(permission: Permission): Boolean {
    return permissions.contains(permission)
  }
}
