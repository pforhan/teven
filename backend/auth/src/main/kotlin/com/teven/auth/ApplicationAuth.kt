package com.teven.auth

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import com.teven.api.model.common.StatusResponse
import com.teven.core.security.JwtConfig
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.Application
import io.ktor.server.application.install
import io.ktor.server.auth.Authentication
import io.ktor.server.auth.jwt.JWTPrincipal
import io.ktor.server.auth.jwt.jwt
import io.ktor.server.response.respond

class ApplicationAuth(
  private val jwtConfig: JwtConfig,
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
              JWTPrincipal(credential.payload)
            } else {
              null
            }
          }
          challenge { _, _ ->
            call.respond(
              HttpStatusCode.Unauthorized,
              StatusResponse("Token is not valid or has expired")
            )
          }
        }
      }

    }
  }
}