package com.teven.service.user

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm.HMAC256
import com.teven.api.model.auth.LoginRequest
import com.teven.api.model.auth.LoginResponse
import com.teven.api.model.auth.LoggedInContextResponse
import com.teven.api.model.organization.OrganizationDetails
import com.teven.api.model.user.CreateUserRequest
import com.teven.api.model.user.UpdateUserRequest
import com.teven.api.model.user.UserResponse
import com.teven.core.config.JwtConfig
import com.teven.core.security.PasswordHasher
import com.teven.data.user.UserDao

class UserService(
  private val userDao: UserDao,
  private val jwtConfig: JwtConfig,
) {
  suspend fun createUser(createUserRequest: CreateUserRequest): UserResponse {
    return userDao.createUser(createUserRequest)
  }

  suspend fun loginUser(loginRequest: LoginRequest): LoginResponse? {
    val user = userDao.getUserByUsername(loginRequest.username)
    return if (user != null && PasswordHasher.checkPassword(
        password = loginRequest.password,
        hashed = user.passwordHash
      )
    ) {
      val token = JWT.create()
        .withAudience(jwtConfig.audience)
        .withIssuer(jwtConfig.issuer)
        .withClaim("userId", user.userId)
        .withClaim("username", user.username)
        .withClaim("role", user.role)
        .sign(HMAC256(jwtConfig.secret))
      LoginResponse(token, user.userId, user.username, user.displayName, user.role)
    } else {
      null
    }
  }

  suspend fun getAllUsers(): List<UserResponse> {
    return userDao.getAllUsers()
  }

  suspend fun getUserById(userId: Int): UserResponse? {
    return userDao.getUserById(userId)
  }

  suspend fun getUserByUsername(username: String): UserResponse? {
    return userDao.getUserByUsername(username)
  }

  suspend fun updateUser(userId: Int, updateUserRequest: UpdateUserRequest): UserResponse? {
    return userDao.updateUser(userId, updateUserRequest)
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
      LoggedInContextResponse(
        user = user,
        // TODO fetch organization details
        organization = OrganizationDetails(1, "Teven Inc.", "contact@teven.com"), // Dummy data
        // TODO fetch permissions
        permissions = listOf("read:event", "create:event") // Dummy data
      )
    } else {
      null
    }
  }
}