package com.teven.app

import com.teven.api.model.role.CreateRoleRequest
import com.teven.api.model.user.CreateUserRequest
import com.teven.core.security.Permission
import com.teven.service.role.RoleService
import com.teven.service.user.UserService

suspend fun seedInitialData(userService: UserService, roleService: RoleService) {
  // 1. Seed the SuperAdmin Role and User
  if (roleService.getRoleByName("SuperAdmin") == null) {
    roleService.createRole(
      CreateRoleRequest(
      roleName = "SuperAdmin",
      permissions = Permission.values().map { it.name }
    ))
    val superAdminEmail = System.getenv("SUPERADMIN_EMAIL")
    val superAdminPassword = System.getenv("SUPERADMIN_PASSWORD")

    if (superAdminEmail.isNullOrBlank() || superAdminPassword.isNullOrBlank()) {
      throw IllegalStateException("SUPERADMIN_EMAIL and SUPERADMIN_PASSWORD environment variables must be set to bootstrap the initial admin user.")
    }

    val existingUser = userService.getUserByUsername(superAdminEmail)
    if (existingUser == null) {
      val superAdmin = userService.createUser(
        CreateUserRequest(
          username = superAdminEmail,
          email = superAdminEmail,
          password = superAdminPassword,
          displayName = "Super Admin"
        )
      )
      // TODO we should set up a "teven" organization for the super admin user but no other users should be in it.
      val superAdminRole = roleService.getRoleByName("SuperAdmin")!!
      roleService.assignRoleToUser(superAdmin.userId, superAdminRole.roleId)
    }
  }

  // 2. Seed the Organizer Role
  if (roleService.getRoleByName("Organizer") == null) {
    roleService.createRole(
      CreateRoleRequest(
        roleName = "Organizer",
        permissions = listOf(
          Permission.MANAGE_USERS_SELF.name,
          Permission.VIEW_USERS_ORGANIZATION.name,
          Permission.MANAGE_USERS_ORGANIZATION.name,
          Permission.VIEW_CUSTOMERS_ORGANIZATION.name,
          Permission.MANAGE_CUSTOMERS_ORGANIZATION.name,
          Permission.VIEW_EVENTS_ORGANIZATION.name,
          Permission.MANAGE_EVENTS_ORGANIZATION.name,
          Permission.ASSIGN_STAFF_TO_EVENTS_ORGANIZATION.name,
          Permission.VIEW_INVENTORY_ORGANIZATION.name,
          Permission.MANAGE_INVENTORY_ORGANIZATION.name,
          Permission.VIEW_REPORTS_ORGANIZATION.name
        )
      )
    )
  }

  // 3. Seed the Staff Role
  if (roleService.getRoleByName("Staff") == null) {
    roleService.createRole(
      CreateRoleRequest(
        roleName = "Staff",
        permissions = listOf(
          Permission.MANAGE_USERS_SELF.name,
          Permission.VIEW_EVENTS_ORGANIZATION.name
        )
      )
    )
  }
}
