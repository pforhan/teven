package alphainterplanetary.teven.auth

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import alphainterplanetary.teven.api.model.common.failure
import alphainterplanetary.teven.core.security.JwtConfig
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.core.security.UserPrincipal
import alphainterplanetary.teven.core.service.UserService
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.Application
import io.ktor.server.application.install
import io.ktor.server.auth.Authentication
import io.ktor.server.auth.jwt.jwt
import io.ktor.server.response.respond

class ApplicationAuth(
  private val jwtConfig: JwtConfig,
  private val userService: UserService,
) {
  fun configureJwt(application: Application) {
    application.apply {
      install(Authentication) {
        jwt("auth-jwt") {
          realm = "Access to 'teven'"
          verifier(
            JWT.require(Algorithm.HMAC256(jwtConfig.secret))
              .withAudience(jwtConfig.audience)
              .withIssuer(jwtConfig.issuer)
              .build()
          )
          validate { credential ->
            if (credential.payload.audience.contains(jwtConfig.audience)) {
              val userId = credential.payload.getClaim("userId").asInt()
              if (userId != null) {
                val context = userService.getUserContext(userId)
                UserPrincipal(
                  userId = context.user.userId,
                  organizationId = context.user.organization.organizationId,
                  permissions = context.permissions.map { Permission.valueOf(it) }.toSet()
                )
              } else {
                null
              }
            } else {
              null
            }
          }
          challenge { _, _ ->
            call.respond(
              HttpStatusCode.Unauthorized,
              failure("Token is not valid or has expired")
            )
          }
        }
      }

    }
  }
}