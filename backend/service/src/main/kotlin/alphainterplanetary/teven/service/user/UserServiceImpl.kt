package alphainterplanetary.teven.service.user

import alphainterplanetary.teven.api.model.auth.LoggedInContextResponse
import alphainterplanetary.teven.api.model.user.UpdateUserRequest
import alphainterplanetary.teven.api.model.user.UserResponse
import alphainterplanetary.teven.core.Constants
import alphainterplanetary.teven.core.service.RoleService
import alphainterplanetary.teven.core.service.UserService
import alphainterplanetary.teven.core.user.User
import alphainterplanetary.teven.data.user.UserDao
import alphainterplanetary.teven.service.invitation.InvitationService

class UserServiceImpl(
  private val userDao: UserDao,
  private val roleService: RoleService,
  private val invitationService: InvitationService,
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
    username: String,
    password: String,
    email: String,
    displayName: String,
    organizationId: Int,
    roleId: Int,
  ): Int {
    val user = userDao.createUser(
      username = username,
      password = password,
      email = email,
      displayName = displayName,
      organizationId = organizationId,
    )
    roleService.assignRoleToUser(user.userId, roleId)
    return user.userId
  }

  override suspend fun getAllUsers(callerId: Int, organizationId: Int?): List<UserResponse> {
    val callerRoles = roleService.getRolesForUser(callerId)
    val isSuperAdmin = callerRoles.any { it.roleName == Constants.ROLE_SUPERADMIN }

    val orgIdToUse = if (isSuperAdmin) {
      organizationId
    } else {
      userDao.getOrganizationForUser(callerId).organizationId
    }

    val users = if (orgIdToUse != null) {
      userDao.getUsersByOrganization(orgIdToUse)
    } else {
      userDao.getAllUsers()
    }
    return users.map { toUserResponse(it) }
  }

  override suspend fun getUserById(userId: Int): UserResponse? =
    userDao.getUserById(userId)?.let { toUserResponse(it) }

  override suspend fun getUserByUsername(username: String): UserResponse? =
    userDao.getUserByUsername(username)?.let { toUserResponse(it) }

  override suspend fun getUserByEmail(email: String): UserResponse? =
    userDao.getUserByEmail(email)?.let { toUserResponse(it) }

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