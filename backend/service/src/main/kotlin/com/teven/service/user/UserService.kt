package com.teven.service.user

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm.HMAC256
import com.teven.api.model.auth.LoggedInContextResponse
import com.teven.api.model.auth.LoginRequest
import com.teven.api.model.auth.LoginResponse
import com.teven.api.model.organization.OrganizationDetails
import com.teven.api.model.user.CreateUserRequest
import com.teven.api.model.user.UpdateUserRequest
import com.teven.api.model.user.UserResponse
import com.teven.core.config.JwtConfig
import com.teven.core.security.AuthorizationException
import com.teven.core.security.PasswordHasher
import com.teven.data.organization.OrganizationDao
import com.teven.data.user.User
import com.teven.data.user.UserDao
import com.teven.service.role.RoleService
import io.ktor.http.HttpStatusCode

class UserService(
  private val userDao: UserDao,
  private val jwtConfig: JwtConfig,
  private val organizationDao: OrganizationDao,
  private val roleService: RoleService,
) {
  private suspend fun toUserResponse(user: User): UserResponse {
    val roles = roleService.getRolesForUser(user.userId)
    return UserResponse(
      userId = user.userId,
      username = user.username,
      email = user.email,
      displayName = user.displayName,
      roles = roles.map { it.roleName },
    )
  }

  suspend fun createUser(createUserRequest: CreateUserRequest, callerId: Int): UserResponse {
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

  suspend fun loginUser(loginRequest: LoginRequest): LoginResponse? {
    val user = userDao.getUserByUsername(loginRequest.username)
    return if (user != null && PasswordHasher.checkPassword(
        password = loginRequest.password,
        hashed = user.passwordHash
      )
    ) {
      val userResponse = toUserResponse(user)
      val token = JWT.create()
        .withAudience(jwtConfig.audience)
        .withIssuer(jwtConfig.issuer)
        .withClaim("userId", user.userId)
        .withClaim("username", user.username)
        .withClaim("roles", userResponse.roles)
        .sign(HMAC256(jwtConfig.secret))
      LoginResponse(token, userResponse)
    } else {
      null
    }
  }

  suspend fun getAllUsers(): List<UserResponse> {
    val users = userDao.getAllUsers()
    return users.map { toUserResponse(it) }
  }

  suspend fun getUserById(userId: Int): UserResponse? {
    val user = userDao.getUserById(userId)
    return user?.let { toUserResponse(it) }
  }

  suspend fun getUserByUsername(username: String): UserResponse? {
    val user = userDao.getUserByUsername(username)
    return user?.let { toUserResponse(it) }
  }

  suspend fun updateUser(userId: Int, updateUserRequest: UpdateUserRequest): UserResponse? {
    val user = userDao.updateUser(userId, updateUserRequest)
    return user?.let { toUserResponse(it) }
  }

  suspend fun areInSameOrganization(userId1: Int?, userId2: Int?): Boolean {
    if (userId1 == null || userId2 == null) {
      return false
    }
    return userDao.areInSameOrganization(userId1, userId2)
  }

  suspend fun getUserContext(userId: Int): LoggedInContextResponse? {
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