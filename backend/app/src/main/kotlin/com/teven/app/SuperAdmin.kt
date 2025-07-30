package com.teven.app

import com.teven.api.model.auth.RegisterRequest
import com.teven.service.user.UserService
import com.teven.service.role.RoleService

suspend fun setupSuperAdmin(userService: UserService, roleService: RoleService) {
    val superAdminEmail = System.getenv("SUPERADMIN_EMAIL")
    val superAdminPassword = System.getenv("SUPERADMIN_PASSWORD")

    if (superAdminEmail.isNullOrBlank() || superAdminPassword.isNullOrBlank()) {
        throw IllegalStateException("SUPERADMIN_EMAIL and SUPERADMIN_PASSWORD environment variables must be set to bootstrap the initial admin user.")
    }

    val existingUser = userService.getUserByEmail(superAdminEmail)
    println("Super admin: ${existingUser?.username}")
    if (existingUser == null) {
        println("Super admin user not found, creating one...")
        val superAdmin = userService.registerUser(
            RegisterRequest(
                username = superAdminEmail,
                email = superAdminEmail,
                password = superAdminPassword,
                displayName = "Super Admin",
                role = "superadmin"
            )
        )
        var superAdminRole = roleService.getRoleByName("superadmin")
        if (superAdminRole == null) {
            superAdminRole = roleService.createRole(com.teven.api.model.role.CreateRoleRequest(roleName = "superadmin", permissions = listOf("all")))
        }
        roleService.assignRoleToUser(superAdmin.userId, superAdminRole.roleId)
        println("Super admin user created successfully.")
    }
}
