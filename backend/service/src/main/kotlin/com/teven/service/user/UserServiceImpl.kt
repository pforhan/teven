package com.teven.service.user

import com.teven.api.model.auth.LoggedInContextResponse
import com.teven.api.model.organization.OrganizationDetails
import com.teven.api.model.user.CreateUserRequest
import com.teven.api.model.user.UpdateUserRequest
import com.teven.api.model.user.UserResponse
import com.teven.core.security.AuthorizationException
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
) : UserService {
  override suspend fun toUserResponse(user: User): UserResponse {
    val roles = roleService.getRolesForUser(user.userId)
    return UserResponse(
      userId = user.userId,
      username = user.username,
      email = user.email,
      displayName = user.displayName,
      roles = roles.map { it.roleName },
    )
  }

  override suspend fun createUser(createUserRequest: CreateUserRequest, callerId: Int): UserResponse {
    val callerRoles = roleService.getRolesForUser(callerId).map { it.roleName }
    val requestedRoles = createUserRequest.roles

    if (!callerRoles.containsAll(requestedRoles)) {
      throw AuthorizationException(
        code = HttpStatusCode.Forbidden,
        message = "User does not have permission to assign all requested roles."
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

  override suspend fun getAllUsers(): List<UserResponse> {
    val users = userDao.getAllUsers()
    return users.map { toUserResponse(it) }
  }

  override suspend fun getUserById(userId: Int): UserResponse? {
    val user = userDao.getUserById(userId)
    return user?.let { toUserResponse(it) }
  }

  override suspend fun getUserByUsername(username: String): UserResponse? {
    val user = userDao.getUserByUsername(username)
    return user?.let { toUserResponse(it) }
  }

  override suspend fun updateUser(userId: Int, updateUserRequest: UpdateUserRequest): UserResponse? {
    val user = userDao.updateUser(userId, updateUserRequest)
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
      val organization = userDao.getOrganizationForUser(userId)?.let { organizationDao.getOrganizationById(it) }
      val roles = roleService.getRolesForUser(userId)
      val permissions = roles.flatMap { it.permissions }.distinct()
      LoggedInContextResponse(
        user = toUserResponse(user),
        organization = organization?.let { OrganizationDetails(it.organizationId, it.name, it.contactInformation) },
        permissions = permissions
      )
    } else {
      null
    }
  }
}