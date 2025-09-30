package alphainterplanetary.teven

import alphainterplanetary.teven.api.model.common.failure
import alphainterplanetary.teven.app.InitialSetup
import alphainterplanetary.teven.app.configureRouting
import alphainterplanetary.teven.app.di.appModule
import alphainterplanetary.teven.auth.ApplicationAuth
import alphainterplanetary.teven.core.security.AuthorizationException
import alphainterplanetary.teven.core.service.PermissionService
import alphainterplanetary.teven.data.DatabaseFactory
import alphainterplanetary.teven.data.populateTestData
import io.ktor.http.HttpStatusCode
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
    val devMode = System.getenv("DEV_MODE")?.toBoolean() ?: false
    if (devMode) {
      populateTestData()
    }
  }

  val applicationAuth by inject<ApplicationAuth>()
  val permissionService by inject<PermissionService>()

  applicationAuth.configureJwt(this)

  attributes.put(PermissionService.key, permissionService)

  install(StatusPages) {
    exception<AuthorizationException> { call, cause ->
      cause.printStackTrace()
      call.respond(
        cause.code,
        failure(cause.message ?: "Authorization error")
      )
    }

    exception<Throwable> { call, cause ->
      cause.printStackTrace()
      call.respond(
        HttpStatusCode.InternalServerError,
        failure("Internal server error", cause.stackTraceToString())
      )
    }

    status(HttpStatusCode.InternalServerError) { call, status ->
      call.respond(status, failure("Internal server error: who knows why"))
    }
  }

  configureRouting()
}