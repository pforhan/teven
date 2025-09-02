package com.teven


import com.teven.api.model.common.StatusResponse
import com.teven.app.InitialSetup
import com.teven.app.configureRouting
import com.teven.app.di.appModule
import com.teven.auth.ApplicationAuth
import com.teven.auth.createAuthorizationPlugin
import com.teven.core.security.AuthorizationException
import com.teven.core.service.RoleService
import com.teven.data.DatabaseFactory
import io.ktor.serialization.kotlinx.json.json
import io.ktor.server.application.Application
import io.ktor.server.application.install
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

  val initialSetup by inject<InitialSetup>()
  runBlocking {
    initialSetup.seedInitialData()
  }
  val roleService by inject<RoleService>()
  val applicationAuth by inject<ApplicationAuth>()

  applicationAuth.configureJwt(this)

  install(createAuthorizationPlugin(roleService))

  install(StatusPages) {
    exception<AuthorizationException> { call, cause ->
      call.respond(cause.code, StatusResponse(cause.message ?: ""))
    }
  }

  configureRouting()
}




