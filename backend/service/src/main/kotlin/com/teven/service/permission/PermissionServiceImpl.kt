package com.teven.service.permission

import com.teven.core.security.Permission
import com.teven.core.security.UserPermissions
import com.teven.core.service.PermissionService
import com.teven.core.service.RoleService

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