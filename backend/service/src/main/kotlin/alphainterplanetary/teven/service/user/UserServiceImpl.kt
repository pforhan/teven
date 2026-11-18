package alphainterplanetary.teven.service.user

import alphainterplanetary.teven.api.model.common.PaginatedResponse
import alphainterplanetary.teven.api.model.auth.LoggedInContextResponse
import alphainterplanetary.teven.api.model.invitation.AcceptInvitationRequest
import alphainterplanetary.teven.api.model.role.RoleResponse
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
import alphainterplanetary.teven.data.user.StaffDetailsDao
import alphainterplanetary.teven.data.user.UserDao
import alphainterplanetary.teven.data.user.UserStatusFilter
import io.ktor.http.HttpStatusCode
import java.time.format.DateTimeFormatter

class UserServiceImpl(
  private val userDao: UserDao,
  private val roleService: RoleService,
  private val staffDetailsDao: StaffDetailsDao,
) : UserService {
  override suspend fun toUserResponse(user: User): UserResponse {
    val roles = roleService.getRolesForUser(user.userId)
    val organization = userDao.getOrganizationForUser(user.userId)
    val staffDetails = staffDetailsDao.getByUserId(user.userId)
    return UserResponse(
      userId = user.userId,
      username = user.username,
      email = user.email,
      displayName = user.displayName,
      roles = roles.map { it.roleName },
      staffDetails = staffDetails,
      organization = organization,
      deletedAt = user.deletedAt?.format(DateTimeFormatter.ISO_OFFSET_DATE_TIME),
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
      val role = authContext.verifyAssignableAndGetRole(it)
      roleService.assignRoleToUser(user.userId, role.roleId)
    }

    createUserRequest.staffDetails?.let { staffDetailsDao.upsert(user.userId, it) }

    return toUserResponse(user)
  }

  private suspend fun AuthContext.verifyAssignableAndGetRole(
    roleName: String,
  ): RoleResponse {
    // Permission check for role assignment
    val requiredPermission = when (roleName) {
      Constants.ROLE_SUPERADMIN -> Permission.CAN_ASSIGN_SUPERADMIN
      Constants.ROLE_ORGANIZER -> Permission.CAN_ASSIGN_ORGANIZER
      Constants.ROLE_STAFF -> Permission.CAN_ASSIGN_STAFF
      else -> throw IllegalArgumentException("Unknown role: $roleName")
    }

    if (!hasPermission(requiredPermission)) {
      throw AuthorizationException(
        code = HttpStatusCode.Forbidden,
        message = "Not authorized to assign role: $roleName"
      )
    }

    return roleService.getRoleByName(roleName)
      ?: throw IllegalArgumentException("Role not found: $roleName")
  }

  override suspend fun createUserFromInvitation(
    request: AcceptInvitationRequest,
    invitation: Invitation,
  ): Int {
    val user = userDao.createUser(request.toCreateUserRequest(invitation.organizationId))
    roleService.assignRoleToUser(user.userId, invitation.roleId)
    return user.userId
  }

  override suspend fun getUsers(
    authContext: AuthContext,
    organizationId: Int?,
    search: String?,
    limit: Int?,
    offset: Long?,
    sortBy: String?,
    sortOrder: String?,
    status: String?,
  ): PaginatedResponse<UserResponse> {
    val canViewGlobal = authContext.hasPermission(Permission.VIEW_USERS_GLOBAL)
    val orgIdToUse = if (canViewGlobal) organizationId else authContext.organizationId

    val canRequestDeactivated =
      canViewGlobal ||
        authContext.hasPermission(Permission.MANAGE_USERS_GLOBAL) ||
        authContext.hasPermission(Permission.MANAGE_USERS_ORGANIZATION)

    val statusFilter = if (canRequestDeactivated) {
      when (status?.lowercase()) {
        "deactivated", "deleted", "inactive" -> UserStatusFilter.DEACTIVATED
        "all" -> UserStatusFilter.ALL
        else -> UserStatusFilter.ACTIVE
      }
    } else {
      UserStatusFilter.ACTIVE
    }

    val usersPaginated = userDao.getUsers(
      organizationId = orgIdToUse,
      search = search,
      limit = limit,
      offset = offset,
      sortBy = sortBy,
      sortOrder = sortOrder,
      status = statusFilter,
    )

    return PaginatedResponse(
      items = usersPaginated.items.map { toUserResponse(it) },
      total = usersPaginated.total,
      offset = usersPaginated.offset,
      limit = usersPaginated.limit,
    )
  }

  override suspend fun getAllUsers(authContext: AuthContext, organizationId: Int?): List<UserResponse> {
    val canViewGlobal = authContext.hasPermission(Permission.VIEW_USERS_GLOBAL)
    val orgIdToUse = if (canViewGlobal) organizationId else authContext.organizationId

    val users = if (orgIdToUse != null) {
      userDao.getUsersByOrganization(orgIdToUse)
    } else {
      userDao.getAllUsers()
    }
    return users.map { toUserResponse(it) }
  }

  override suspend fun getUserById(userId: Int, authContext: AuthContext?): UserResponse? {
    val isGlobalViewer = authContext?.hasPermission(Permission.VIEW_USERS_GLOBAL) == true
    val isGlobalManager = authContext?.hasPermission(Permission.MANAGE_USERS_GLOBAL) == true
    val isOrgManager = authContext?.hasPermission(Permission.MANAGE_USERS_ORGANIZATION) == true
    val canViewDeactivated = isGlobalViewer || isGlobalManager || isOrgManager
    val user = userDao.findUserById(userId, includeDeactivated = canViewDeactivated) ?: return null
    if (user.deletedAt != null) {
      if (authContext == null) return null
      val sameOrg = authContext.organizationId == userDao.getOrganizationForUser(userId).organizationId
      val allowed = isGlobalViewer || isGlobalManager || (isOrgManager && sameOrg)
      if (!allowed || !sameOrg) return null
    } else if (authContext != null && !isGlobalViewer && !isGlobalManager) {
      // org-scoped viewers/managers must only see users in their org
      val sameOrg = userDao.areInSameOrganization(authContext.userId, userId)
      if (!sameOrg) return null
    }
    return toUserResponse(user)
  }

  override suspend fun getUserByUsername(username: String): UserResponse? =
    userDao.getUserByUsername(username)?.let { toUserResponse(it) }

  override suspend fun getUserByEmail(email: String): UserResponse? =
    userDao.getUserByEmail(email)?.let { toUserResponse(it) }

  override suspend fun updateUser(
    userId: Int,
    updateUserRequest: UpdateUserRequest,
    authContext: AuthContext
  ): UserResponse? {
    val target = userDao.findUserById(userId, includeDeactivated = true) ?: return null
    if (target.deletedAt != null) return null
    val canManageGlobal = authContext.hasPermission(Permission.MANAGE_USERS_GLOBAL)
    if (!canManageGlobal) {
      val sameOrg = userDao.areInSameOrganization(authContext.userId, userId)
      if (!sameOrg) throw AuthorizationException(HttpStatusCode.Forbidden, "Not authorized to update this user.")
    }
    val user = userDao.updateUser(userId, updateUserRequest)
    updateUserRequest.staffDetails?.let { staffDetailsDao.upsert(userId, it) }
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
        val role = authContext.verifyAssignableAndGetRole(roleName)
        roleService.assignRoleToUser(userId, role.roleId)
      }
    }
    return user?.let { toUserResponse(it) }
  }

  override suspend fun deactivateUser(userId: Int, authContext: AuthContext): Boolean {
    if (authContext.userId == userId) {
      throw AuthorizationException(HttpStatusCode.Forbidden, "Users cannot deactivate themselves.")
    }
    val target = userDao.findUserById(userId, includeDeactivated = true) ?: return false
    val canManageGlobal = authContext.hasPermission(Permission.MANAGE_USERS_GLOBAL)
    if (!canManageGlobal) {
      val sameOrg = userDao.areInSameOrganization(authContext.userId, userId)
      if (!sameOrg) throw AuthorizationException(HttpStatusCode.Forbidden, "Not authorized to deactivate this user.")
    }
    if (target.deletedAt != null) return true
    val targetRoles = roleService.getRolesForUser(userId).map { it.roleName }
    if (Constants.ROLE_SUPERADMIN in targetRoles) {
      // prevent deactivating last super-admin
      val allUsers = userDao.getAllUsers(includeDeactivated = true)
      val activeSuperAdmins = allUsers.count { u ->
        u.deletedAt == null && roleService.getRolesForUser(u.userId).any { it.roleName == Constants.ROLE_SUPERADMIN }
      }
      if (activeSuperAdmins <= 1) {
        throw AuthorizationException(HttpStatusCode.Forbidden, "Cannot deactivate the last super-admin.")
      }
    }
    return userDao.deactivateUser(userId)
  }

  override suspend fun restoreUser(userId: Int, authContext: AuthContext): UserResponse? {
    val target = userDao.findUserById(userId, includeDeactivated = true) ?: return null
    val canManageGlobal = authContext.hasPermission(Permission.MANAGE_USERS_GLOBAL)
    if (!canManageGlobal) {
      val canManageOrg = authContext.hasPermission(Permission.MANAGE_USERS_ORGANIZATION)
      val sameOrg = canManageOrg && userDao.areInSameOrganization(authContext.userId, userId)
      if (!sameOrg) {
        throw AuthorizationException(HttpStatusCode.Forbidden, "Not authorized to restore this user.")
      }
    }

    if (target.deletedAt == null) return toUserResponse(target)
    userDao.restoreUser(userId)
    val restored = userDao.findUserById(userId, includeDeactivated = false) ?: return null
    return toUserResponse(restored)
  }

  override suspend fun areInSameOrganization(userId1: Int?, userId2: Int?): Boolean {
    if (userId1 == null || userId2 == null) {
      return false
    }
    return userDao.areInSameOrganization(userId1, userId2)
  }

  override suspend fun getUserContext(userId: Int): LoggedInContextResponse {
    val user = userDao.findUserById(userId, includeDeactivated = false)
      ?: throw AuthorizationException(HttpStatusCode.Unauthorized, "User is deactivated or not found.")
    return LoggedInContextResponse(
      user = toUserResponse(user),
      permissions = roleService.getRolesForUser(userId).flatMap { it.permissions }.distinct()
    )
  }
}