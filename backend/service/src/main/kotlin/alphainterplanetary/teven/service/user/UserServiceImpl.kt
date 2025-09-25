package alphainterplanetary.teven.service.user

import alphainterplanetary.teven.api.model.auth.LoggedInContextResponse
import alphainterplanetary.teven.api.model.invitation.AcceptInvitationRequest
import alphainterplanetary.teven.api.model.user.CreateUserRequest
import alphainterplanetary.teven.api.model.user.UpdateUserRequest
import alphainterplanetary.teven.api.model.user.UserResponse
import alphainterplanetary.teven.core.Constants
import alphainterplanetary.teven.core.security.AuthContext
import alphainterplanetary.teven.core.security.AuthorizationException
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.core.service.RoleService
import alphainterplanetary.teven.core.service.UserService
import alphainterplanetary.teven.core.user.Invitation
import alphainterplanetary.teven.core.user.User
import alphainterplanetary.teven.data.user.UserDao
import alphainterplanetary.teven.service.invitation.InvitationService
import io.ktor.http.HttpStatusCode
import io.ktor.server.auth.ForbiddenResponse

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
    authContext: AuthContext,
  ): UserResponse {
    val organizationIdToUse = createUserRequest.organizationId

    // Permission check for organizationId
    if (!authContext.hasPermission(Permission.MANAGE_USERS_GLOBAL) &&
      authContext.organizationId != organizationIdToUse
    ) {
      throw SecurityException("Not authorized to create users for this organization.")
    }

    val user = userDao.createUser(createUserRequest.copy(organizationId = organizationIdToUse))

    val requestedRoles = createUserRequest.roles
    requestedRoles.forEach {
      val role =
        roleService.getRoleByName(it) ?: throw IllegalArgumentException("Role not found: $it")

      // Permission check for role assignment
      val requiredPermission = when (role.roleName) {
        Constants.ROLE_SUPERADMIN -> Permission.CAN_ASSIGN_SUPERADMIN
        Constants.ROLE_ORGANIZER -> Permission.CAN_ASSIGN_ORGANIZER
        Constants.ROLE_STAFF -> Permission.CAN_ASSIGN_STAFF
        else -> Permission.ASSIGN_ROLES_ORGANIZATION // Default for other roles
      }

      if (!authContext.hasPermission(requiredPermission)) {
        throw AuthorizationException(
          code = HttpStatusCode.Forbidden,
          message = "Not authorized to assign role: $it"
        )
      }
      roleService.assignRoleToUser(user.userId, role.roleId)
    }

    return toUserResponse(user)
  }

  override suspend fun createUserFromInvitation(
    request: AcceptInvitationRequest,
    invitation: Invitation,
  ): Int {
    val user = userDao.createUser(request.toCreateUserRequest(invitation.organizationId))
    roleService.assignRoleToUser(user.userId, invitation.roleId)
    return user.userId
  }

  override suspend fun getAllUsers(authContext: AuthContext, organizationId: Int?): List<UserResponse> {
    val isSuperAdmin = authContext.hasPermission(Permission.VIEW_USERS_GLOBAL)

    val orgIdToUse = if (isSuperAdmin) {
      organizationId
    } else {
      authContext.organizationId
    }

    val users = if (orgIdToUse != null) {
      userDao.getUsersByOrganization(orgIdToUse)
    } else {
      userDao.getAllUsers()
    }
    return users.map { toUserResponse(it) }
  }

  override suspend fun getUserById(userId: Int): UserResponse? =
    toUserResponse(userDao.getUserById(userId))

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