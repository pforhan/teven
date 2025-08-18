package com.teven.auth

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import com.teven.api.model.auth.LoginRequest
import com.teven.api.model.auth.LoginResponse
import com.teven.core.service.AuthService
import com.teven.core.service.UserService
import com.teven.data.user.UserDao
import org.mindrot.jbcrypt.BCrypt
import java.util.Date

class AuthServiceImpl(
  private val userDao: UserDao,
  private val userService: UserService,
) : AuthService {
  override suspend fun loginUser(loginRequest: LoginRequest): LoginResponse? {
    val user = userDao.getUserByUsername(loginRequest.username)
    if (user != null && BCrypt.checkpw(loginRequest.password, user.passwordHash)) {
      val token = JWT.create()
        .withAudience("jwt-audience")
        .withIssuer("jwt-issuer")
        .withClaim("userId", user.userId)
        .withExpiresAt(Date(System.currentTimeMillis() + 600000))
        .sign(Algorithm.HMAC256("jwt-secret"))
      val userResponse = userService.toUserResponse(user)
      return LoginResponse(token, userResponse)
    }
    return null
  }
}
