package com.teven.service.user

import com.teven.api.model.auth.LoggedInContextResponse
import com.teven.api.model.organization.Organization
import com.teven.api.model.organization.OrganizationDetails
import com.teven.api.model.user.CreateUserRequest
import com.teven.api.model.user.UpdateUserRequest
import com.teven.api.model.user.UserResponse
import com.teven.core.service.RoleService
import com.teven.core.service.UserService
import com.teven.core.user.User
import com.teven.data.organization.OrganizationDao
import com.teven.data.user.UserDao

class UserServiceImpl(
  private val userDao: UserDao,
  private val organizationDao: OrganizationDao,
  private val roleService: RoleService,
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
      organization = organization?.let { Organization(it.name) }
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

  // TODO I don't think this is correct -- if a superadmin has an org it should still get all users
  override suspend fun getAllUsers(callerId: Int): List<UserResponse> {
    val organizationId = userDao.getOrganizationForUser(callerId)
    val users = if (organizationId != null) {
      userDao.getUsersByOrganization(organizationId)
    } else {
      userDao.getAllUsers()
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
