package com.teven.app

import com.teven.api.model.organization.CreateOrganizationRequest
import com.teven.api.model.role.CreateRoleRequest
import com.teven.api.model.user.CreateUserRequest
import com.teven.core.Constants
import com.teven.core.security.Permission
import com.teven.core.service.RoleService
import com.teven.core.service.UserService
import com.teven.service.organization.OrganizationService

suspend fun seedInitialData(userService: UserService, roleService: RoleService, organizationService: OrganizationService) {
  // 1. Seed the SuperAdmin Role and User
  if (roleService.getRoleByName(Constants.ROLE_SUPERADMIN) == null) {
    roleService.createRole(
      CreateRoleRequest(
      roleName = Constants.ROLE_SUPERADMIN,
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
        ), 0
      )
      val tevenOrganization = organizationService.createOrganization(
        CreateOrganizationRequest(
          name = "Teven",
          contactInformation = "admin@teven.com"
        )
      )
      organizationService.assignUserToOrganization(superAdmin.userId, tevenOrganization.organizationId, 0)
      val superAdminRole = roleService.getRoleByName(Constants.ROLE_SUPERADMIN)!!
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
