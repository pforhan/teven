package com.teven.service.user

import com.teven.api.model.auth.LoggedInContextResponse
import com.teven.api.model.user.CreateUserRequest
import com.teven.api.model.user.UpdateUserRequest
import com.teven.api.model.user.UserResponse
import com.teven.core.service.RoleService
import com.teven.core.service.UserService
import com.teven.core.user.User
import com.teven.data.user.UserDao

class UserServiceImpl(
  private val userDao: UserDao,
  private val roleService: RoleService,
) : UserService {
  override suspend fun toUserResponse(user: User): UserResponse {
    val roles = roleService.getRolesForUser(user.userId)
    val organization = userDao.getOrganizationForUser(user.userId)
    return UserResponse(
      userId = user.userId,
      username = user.username,
      email = user.email,
      displayName = user.displayName,
      roles = roles.map { it.roleName },
      organization = organization,
    )
  }

  override suspend fun createUser(
    createUserRequest: CreateUserRequest,
  ): UserResponse {
    val user = userDao.createUser(createUserRequest)
    val requestedRoles = createUserRequest.roles
    requestedRoles.forEach {
      roleService.getRoleByName(it)?.let { role ->
        roleService.assignRoleToUser(user.userId, role.roleId)
      }
    }
    return toUserResponse(user)
  }

  override suspend fun getAllUsers(callerId: Int): List<UserResponse> {
    val callerRoles = roleService.getRolesForUser(callerId)
    val isSuperAdmin = callerRoles.any { it.roleName == "superadmin" }

    val users = if (isSuperAdmin) {
      userDao.getAllUsers()
    } else {
      val organizationId = userDao.getOrganizationForUser(callerId).organizationId
      userDao.getUsersByOrganization(organizationId)
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
  ): UserResponse? {
    val user = userDao.updateUser(userId, updateUserRequest)
    val requestedRoles = updateUserRequest.roles
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

  override suspend fun getUserContext(userId: Int): LoggedInContextResponse =
    LoggedInContextResponse(
      user = toUserResponse(userDao.getUserById(userId)),
      permissions = roleService.getRolesForUser(userId).flatMap { it.permissions }.distinct()
    )
}
