package alphainterplanetary.teven.service.permission

import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.core.security.UserPermissions
import alphainterplanetary.teven.core.service.PermissionService
import alphainterplanetary.teven.core.service.RoleService

class PermissionServiceImpl(
  private val roleService: RoleService,
) : PermissionService {
  override suspend fun getPermissions(callerId: Int): UserPermissions {
    val callerRoles = roleService.getRolesForUser(callerId)
    val callerRoleNames = callerRoles.map { it.roleName }
    val callerPermissions =
      callerRoles.flatMap { it.permissions }.distinct().mapNotNull { permissionName ->
        try {
          Permission.valueOf(permissionName)
        } catch (e: IllegalArgumentException) {
          null
        }
      }
    return UserPermissions(callerRoleNames, callerPermissions)
  }
}