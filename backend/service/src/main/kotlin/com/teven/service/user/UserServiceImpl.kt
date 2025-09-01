package com.teven.service.user

import com.teven.api.model.auth.LoggedInContextResponse
import com.teven.api.model.organization.OrganizationDetails
import com.teven.api.model.user.CreateUserRequest
import com.teven.api.model.user.UpdateUserRequest
import com.teven.api.model.user.UserResponse
import com.teven.core.Constants
import com.teven.core.security.AuthorizationException
import com.teven.core.security.Permission.ASSIGN_ROLES_GLOBAL
import com.teven.core.security.Permission.ASSIGN_ROLES_ORGANIZATION
import com.teven.core.security.Permission.MANAGE_USERS_GLOBAL
import com.teven.core.security.Permission.MANAGE_USERS_ORGANIZATION
import com.teven.core.security.Permission.MANAGE_USERS_SELF
import com.teven.core.security.Permission.VIEW_USERS_GLOBAL
import com.teven.core.security.Permission.VIEW_USERS_ORGANIZATION
import com.teven.core.service.PermissionService
import com.teven.core.service.RoleService
import com.teven.core.service.UserService
import com.teven.core.user.User
import com.teven.data.organization.OrganizationDao
import com.teven.data.user.UserDao
import io.ktor.http.HttpStatusCode

class UserServiceImpl(
  private val userDao: UserDao,
  private val organizationDao: OrganizationDao,
  private val roleService: RoleService,
  private val permissionService: PermissionService,
) : UserService {
  override suspend fun toUserResponse(user: User): UserResponse {
    val roles = roleService.getRolesForUser(user.userId)
    val organization =
      userDao.getOrganizationForUser(user.userId)?.let { organizationDao.getOrganizationById(it) }
    return UserResponse(
      userId = user.userId,
      username = user.username,
      email = user.email,
      displayName = user.displayName,
      roles = roles.map { it.roleName },
      organization = organization?.let { com.teven.api.model.organization.Organization(it.name) }
    )
  }

  override suspend fun createUser(
    createUserRequest: CreateUserRequest,
    callerId: Int,
  ): UserResponse {
    val callerPermissions = permissionService.getPermissions(callerId)
    val requestedRoles = createUserRequest.roles

    if (requestedRoles.contains(Constants.ROLE_SUPERADMIN) && !callerPermissions.isSuperAdmin) {
      throw AuthorizationException(
        code = HttpStatusCode.Forbidden,
        message = "Only SuperAdmins can assign the SuperAdmin role."
      )
    }

    if (!callerPermissions.hasAnyPermissions(ASSIGN_ROLES_GLOBAL, ASSIGN_ROLES_ORGANIZATION)) {
      throw AuthorizationException(
        code = HttpStatusCode.Forbidden,
        message = "User does not have permission to assign roles."
      )
    }

    val user = userDao.createUser(createUserRequest)
    requestedRoles.forEach {
      roleService.getRoleByName(it)?.let { role ->
        roleService.assignRoleToUser(user.userId, role.roleId)
      }
    }
    return toUserResponse(user)
  }

  override suspend fun getAllUsers(callerId: Int): List<UserResponse> {
    val callerPermissions = permissionService.getPermissions(callerId)

    val users = when {
      callerPermissions.hasPermission(VIEW_USERS_GLOBAL) -> userDao.getAllUsers()
      callerPermissions.hasPermission(VIEW_USERS_ORGANIZATION) -> {
        val organizationId = userDao.getOrganizationForUser(callerId)
        if (organizationId != null) {
          userDao.getUsersByOrganization(organizationId)
        } else {
          emptyList()
        }
      }

      else -> throw SecurityException("User does not have permission to view users.")
    }
    return users.map { toUserResponse(it) }
  }

  override suspend fun getUserById(userId: Int): UserResponse? =
    userDao.getUserById(userId)?.let { toUserResponse(it) }

  override suspend fun getUserByUsername(username: String): UserResponse? =
    userDao.getUserByUsername(username)?.let { toUserResponse(it) }

  override suspend fun updateUser(
    userId: Int,
    updateUserRequest: UpdateUserRequest,
    callerId: Int,
  ): UserResponse? {
    val callerPermissions = permissionService.getPermissions(callerId)
    val targetUserCurrentRoles = roleService.getRolesForUser(userId).map { it.roleName }
    val requestedRoles = updateUserRequest.roles

    if (requestedRoles != null) {
      val isAssigningSuperAdmin = requestedRoles.contains(Constants.ROLE_SUPERADMIN)
      val isRevokingSuperAdmin =
        targetUserCurrentRoles.contains(Constants.ROLE_SUPERADMIN) && !isAssigningSuperAdmin

      if ((isAssigningSuperAdmin || isRevokingSuperAdmin) && !callerPermissions.isSuperAdmin) {
        throw AuthorizationException(
          code = HttpStatusCode.Forbidden,
          message = "Only SuperAdmins can assign or revoke the SuperAdmin role."
        )
      }

      if (!callerPermissions.hasAnyPermissions(ASSIGN_ROLES_GLOBAL, ASSIGN_ROLES_ORGANIZATION)) {
        throw AuthorizationException(
          code = HttpStatusCode.Forbidden,
          message = "User does not have permission to assign roles."
        )
      }
    }

    when {
      callerId == userId -> {
        if (!callerPermissions.hasPermission(MANAGE_USERS_SELF)) {
          throw SecurityException("User does not have permission to manage their own profile.")
        }
      }

      callerPermissions.hasPermission(MANAGE_USERS_GLOBAL) -> {
        // Global permission, no further checks needed
      }

      callerPermissions.hasPermission(MANAGE_USERS_ORGANIZATION) -> {
        if (!areInSameOrganization(callerId, userId)) {
          throw SecurityException("User does not have permission to manage users outside their organization.")
        }
      }

      else -> throw SecurityException("User does not have permission to update users.")
    }

    val user = userDao.updateUser(userId, updateUserRequest)
    if (requestedRoles != null) {
      val currentRoleNames = roleService.getRolesForUser(userId).map { it.roleName }

      // Remove roles that are no longer requested
      currentRoleNames.filter { it !in requestedRoles }.forEach { roleName ->
        roleService.getRoleByName(roleName)?.let { role ->
          roleService.removeRoleFromUser(userId, role.roleId)
        }
      }
      // Add newly requested roles
      requestedRoles.filter { it !in currentRoleNames }.forEach { roleName ->
        roleService.getRoleByName(roleName)?.let { role ->
          roleService.assignRoleToUser(userId, role.roleId)
        }
      }
    }
    return user?.let { toUserResponse(it) }
  }

  override suspend fun areInSameOrganization(userId1: Int?, userId2: Int?): Boolean {
    if (userId1 == null || userId2 == null) {
      return false
    }
    return userDao.areInSameOrganization(userId1, userId2)
  }

  override suspend fun getUserContext(userId: Int): LoggedInContextResponse? {
    val user = userDao.getUserById(userId)

    return if (user != null) {
      val organization =
        userDao.getOrganizationForUser(userId)?.let { organizationDao.getOrganizationById(it) }
      val roles = roleService.getRolesForUser(userId)
      val permissions = roles.flatMap { it.permissions }.distinct()
      LoggedInContextResponse(
        user = toUserResponse(user),
        organization = organization?.let {
          OrganizationDetails(
            it.organizationId,
            it.name,
            it.contactInformation
          )
        },
        permissions = permissions
      )
    } else {
      null
    }
  }
}