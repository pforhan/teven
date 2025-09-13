package com.teven.app

import com.teven.api.model.organization.CreateOrganizationRequest
import com.teven.api.model.role.CreateRoleRequest
import com.teven.api.model.user.CreateUserRequest
import com.teven.core.Constants
import com.teven.core.security.Permission
import com.teven.data.organization.OrganizationDao
import com.teven.data.role.RoleDao
import com.teven.data.user.UserDao

class InitialSetup(
  private val userDao: UserDao,
  private val organizationDao: OrganizationDao,
  private val roleDao: RoleDao,
) {
  suspend fun seedInitialData() {
    // 1. Seed the SuperAdmin Role and User
    if (roleDao.getRoleByName(Constants.ROLE_SUPERADMIN) == null) {
      roleDao.createRole(
        CreateRoleRequest(
          roleName = Constants.ROLE_SUPERADMIN,
          permissions = Permission.entries.map { it.name },
        ),
      )
      val superAdminEmail = System.getenv("SUPERADMIN_EMAIL")
      val superAdminPassword = System.getenv("SUPERADMIN_PASSWORD")

      if (superAdminEmail.isNullOrBlank() || superAdminPassword.isNullOrBlank()) {
        throw IllegalStateException("SUPERADMIN_EMAIL and SUPERADMIN_PASSWORD environment variables must be set to bootstrap the initial admin user.")
      }

      val existingUser = userDao.getUserByUsername(superAdminEmail)
      if (existingUser == null) {
        val tevenOrganization = organizationDao.createOrganization(
          CreateOrganizationRequest(
            name = "Teven",
            contactInformation = "admin@teven.com",
          ),
        )
        val superAdminUser = userDao.createUser(
          CreateUserRequest(
            username = superAdminEmail,
            email = superAdminEmail,
            password = superAdminPassword,
            displayName = "Super Admin",
            organizationId = tevenOrganization.organizationId,
          ),
        )
        val superAdminRole = roleDao.getRoleByName(Constants.ROLE_SUPERADMIN)!!
        roleDao.assignRoleToUser(superAdminUser.userId, superAdminRole.roleId)
      }
    }

    // 2. Seed the Organizer Role
    if (roleDao.getRoleByName("Organizer") == null) {
      roleDao.createRole(
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
            Permission.VIEW_REPORTS_ORGANIZATION.name,
          ),
        ),
      )
    }

    // 3. Seed the Staff Role
    if (roleDao.getRoleByName("Staff") == null) {
      roleDao.createRole(
        CreateRoleRequest(
          roleName = "Staff",
          permissions = listOf(
            Permission.MANAGE_USERS_SELF.name,
            Permission.VIEW_EVENTS_ORGANIZATION.name,
          ),
        ),
      )
    }
  }
}
