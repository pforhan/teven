package alphainterplanetary.teven.auth

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import alphainterplanetary.teven.api.model.auth.LoginRequest
import alphainterplanetary.teven.api.model.auth.LoginResponse
import alphainterplanetary.teven.core.security.JwtConfig
import alphainterplanetary.teven.core.service.AuthService
import alphainterplanetary.teven.core.service.UserService
import alphainterplanetary.teven.data.user.UserDao
import org.mindrot.jbcrypt.BCrypt
import java.util.Date

class AuthServiceImpl(
  private val userDao: UserDao,
  private val userService: UserService,
  private val jwtConfig: JwtConfig,
) : AuthService {
  override suspend fun loginUser(loginRequest: LoginRequest): LoginResponse? {
    val user = userDao.getUserByUsername(loginRequest.username)
    if (user == null) {
      return null
    }
    val passwordMatches = BCrypt.checkpw(loginRequest.password, user.passwordHash)
    if (!passwordMatches) {
      return null
    }

    val token = JWT.create()
      .withAudience(jwtConfig.audience)
      .withIssuer(jwtConfig.issuer)
      .withClaim("userId", user.userId)
      .withExpiresAt(Date(System.currentTimeMillis() + jwtConfig.expirationTimeMillis))
      .sign(Algorithm.HMAC256(jwtConfig.secret))
    return LoginResponse(token, userService.toUserResponse(user))
  }
}