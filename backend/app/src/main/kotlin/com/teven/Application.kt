package com.teven

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import com.teven.api.model.common.StatusResponse
import com.teven.app.auth.createAuthorizationPlugin
import com.teven.app.configureRouting
import com.teven.app.di.appModule
import com.teven.app.seedInitialData
import com.teven.core.config.JwtConfig
import com.teven.data.DatabaseFactory
import com.teven.service.role.RoleService
import com.teven.core.security.AuthorizationException
import com.teven.service.user.UserService
import io.ktor.http.HttpStatusCode
import io.ktor.serialization.kotlinx.json.json
import io.ktor.server.application.Application
import io.ktor.server.application.install
import io.ktor.server.auth.Authentication
import io.ktor.server.auth.jwt.JWTPrincipal
import io.ktor.server.auth.jwt.jwt
import io.ktor.server.engine.embeddedServer
import io.ktor.server.netty.Netty
import io.ktor.server.plugins.contentnegotiation.ContentNegotiation
import io.ktor.server.plugins.statuspages.StatusPages
import io.ktor.server.response.respond
import kotlinx.coroutines.runBlocking
import org.koin.ktor.ext.inject
import org.koin.ktor.plugin.Koin

fun main() {
  embeddedServer(Netty, port = 8080, host = "0.0.0.0", module = Application::module)
    .start(wait = true)
}

fun Application.module() {
  DatabaseFactory.init()
  install(ContentNegotiation) {
    json()
  }
  install(Koin) {
    modules(appModule)
  }

  val userService by inject<UserService>()
  val roleService by inject<RoleService>()
  val organizationService by inject<com.teven.service.organization.OrganizationService>()

  runBlocking {
    seedInitialData(userService, roleService, organizationService)
  }

  val jwtConfig = JwtConfig(
    secret = System.getenv("JWT_SECRET")
      ?: throw IllegalArgumentException("JWT_SECRET environment variable not set"),
    issuer = System.getenv("JWT_ISSUER")
      ?: throw IllegalArgumentException("JWT_ISSUER environment variable not set"),
    audience = System.getenv("JWT_AUDIENCE")
      ?: throw IllegalArgumentException("JWT_AUDIENCE environment variable not set")
  )

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

  install(createAuthorizationPlugin(roleService))

  install(StatusPages) {
    exception<AuthorizationException> { call, cause ->
      call.respond(cause.code, StatusResponse(cause.message ?: ""))
    }
  }

  configureRouting()
}




