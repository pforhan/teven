package alphainterplanetary.teven.core.security

import alphainterplanetary.teven.core.Constants

data class UserPermissions(
  val roles: List<String>,
  val permissions: List<Permission>,
) {
  val isSuperAdmin: Boolean = roles.contains(Constants.ROLE_SUPERADMIN)

  fun hasPermission(permission: Permission): Boolean {
    return isSuperAdmin || permissions.contains(permission)
  }

  fun hasAllPermissions(vararg requiredPermissions: Permission): Boolean {
    return isSuperAdmin || permissions.containsAll(requiredPermissions.asList())
  }

  fun hasAnyPermissions(vararg searchPermissions: Permission): Boolean {
    return isSuperAdmin || permissions.any { searchPermissions.contains(it) }
  }
}