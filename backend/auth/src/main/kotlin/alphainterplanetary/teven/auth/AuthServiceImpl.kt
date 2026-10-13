package alphainterplanetary.teven.auth

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import alphainterplanetary.teven.api.model.auth.LoginRequest
import alphainterplanetary.teven.api.model.auth.LoginResponse
import alphainterplanetary.teven.core.security.JwtConfig
import alphainterplanetary.teven.core.security.PasswordHasher
import alphainterplanetary.teven.core.service.AuthService
import alphainterplanetary.teven.core.service.LoginResult
import alphainterplanetary.teven.core.service.UserService
import alphainterplanetary.teven.data.user.UserDao
import java.util.Date

import org.slf4j.LoggerFactory

class AuthServiceImpl(
  private val userDao: UserDao,
  private val userService: UserService,
  private val jwtConfig: JwtConfig,
) : AuthService {
  private val logger = LoggerFactory.getLogger(AuthServiceImpl::class.java)

  override suspend fun loginUser(loginRequest: LoginRequest): LoginResult {
    logger.info("Attempting login for user: {}", loginRequest.username)
    val user = userDao.getUserByUsername(loginRequest.username)
    if (user == null) {
      logger.warn("User not found: {}", loginRequest.username)
      return LoginResult.UserNotFound
    }
    // Through `PasswordHasher`, not `BCrypt.checkpw` directly. A stored value
    // that is not a bcrypt hash throws inside jBCrypt; the hasher turns that
    // into `false`, so a corrupted row is an invalid password rather than the
    // HTTP 500 with a stack trace it used to be.
    val passwordMatches = PasswordHasher.checkPassword(loginRequest.password, user.passwordHash)
    if (!passwordMatches) {
      logger.warn("Password mismatch for user: {}", loginRequest.username)
      return LoginResult.InvalidPassword
    }

    logger.info("Login successful for user: {}", loginRequest.username)
    val token = JWT.create()
      .withAudience(jwtConfig.audience)
      .withIssuer(jwtConfig.issuer)
      .withClaim("userId", user.userId)
      .withExpiresAt(Date(System.currentTimeMillis() + jwtConfig.expirationTimeMillis))
      .sign(Algorithm.HMAC256(jwtConfig.secret))
    return LoginResult.Success(LoginResponse(token, userService.toUserResponse(user)))
  }
}