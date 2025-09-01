package com.teven.core.security

import com.teven.core.Constants
import org.junit.jupiter.api.Assertions
import org.junit.jupiter.api.Test

class UserPermissionsTest {

    @Test
    fun `isSuperAdmin should return true for superadmin role`() {
        val userPermissions = UserPermissions(roles = listOf(Constants.ROLE_SUPERADMIN), permissions = emptyList())
        Assertions.assertTrue(userPermissions.isSuperAdmin)
    }

    @Test
    fun `isSuperAdmin should return false for other roles`() {
        val userPermissions = UserPermissions(roles = listOf("Admin", "User"), permissions = emptyList())
        Assertions.assertFalse(userPermissions.isSuperAdmin)
    }

    @Test
    fun `hasPermission should return true for superadmin`() {
        val userPermissions = UserPermissions(roles = listOf(Constants.ROLE_SUPERADMIN), permissions = emptyList())
        Assertions.assertTrue(userPermissions.hasPermission(Permission.MANAGE_USERS_GLOBAL))
    }

    @Test
    fun `hasPermission should return true for existing permission`() {
        val userPermissions = UserPermissions(
            roles = listOf("Admin"),
            permissions = listOf(Permission.MANAGE_USERS_ORGANIZATION)
        )
        Assertions.assertTrue(userPermissions.hasPermission(Permission.MANAGE_USERS_ORGANIZATION))
    }

    @Test
    fun `hasPermission should return false for non-existing permission`() {
        val userPermissions = UserPermissions(
            roles = listOf("Admin"),
            permissions = listOf(Permission.MANAGE_USERS_ORGANIZATION)
        )
        Assertions.assertFalse(userPermissions.hasPermission(Permission.MANAGE_USERS_GLOBAL))
    }

    @Test
    fun `hasAllPermissions should return true for superadmin`() {
        val userPermissions = UserPermissions(roles = listOf(Constants.ROLE_SUPERADMIN), permissions = emptyList())
        Assertions.assertTrue(userPermissions.hasAllPermissions(Permission.MANAGE_USERS_GLOBAL, Permission.MANAGE_ROLES_GLOBAL))
    }

    @Test
    fun `hasAllPermissions should return true when all permissions exist`() {
        val userPermissions = UserPermissions(
            roles = listOf("Admin"),
            permissions = listOf(Permission.MANAGE_USERS_ORGANIZATION, Permission.VIEW_USERS_ORGANIZATION)
        )
        Assertions.assertTrue(userPermissions.hasAllPermissions(Permission.MANAGE_USERS_ORGANIZATION, Permission.VIEW_USERS_ORGANIZATION))
    }

    @Test
    fun `hasAllPermissions should return false when some permissions are missing`() {
        val userPermissions = UserPermissions(
            roles = listOf("Admin"),
            permissions = listOf(Permission.MANAGE_USERS_ORGANIZATION)
        )
        Assertions.assertFalse(userPermissions.hasAllPermissions(Permission.MANAGE_USERS_ORGANIZATION, Permission.VIEW_USERS_GLOBAL))
    }

    @Test
    fun `hasAnyPermissions should return true for superadmin`() {
        val userPermissions = UserPermissions(roles = listOf(Constants.ROLE_SUPERADMIN), permissions = emptyList())
        Assertions.assertTrue(userPermissions.hasAnyPermissions(Permission.MANAGE_USERS_GLOBAL, Permission.MANAGE_ROLES_GLOBAL))
    }

    @Test
    fun `hasAnyPermissions should return true when at least one permission exists`() {
        val userPermissions = UserPermissions(
            roles = listOf("Admin"),
            permissions = listOf(Permission.MANAGE_USERS_ORGANIZATION)
        )
        Assertions.assertTrue(userPermissions.hasAnyPermissions(Permission.MANAGE_USERS_ORGANIZATION, Permission.VIEW_USERS_GLOBAL))
    }

    @Test
    fun `hasAnyPermissions should return false when no permissions exist`() {
        val userPermissions = UserPermissions(
            roles = listOf("Admin"),
            permissions = listOf(Permission.MANAGE_USERS_ORGANIZATION)
        )
        Assertions.assertFalse(userPermissions.hasAnyPermissions(Permission.VIEW_USERS_GLOBAL, Permission.MANAGE_ROLES_GLOBAL))
    }
}