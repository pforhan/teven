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
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.serialization.kotlinx.json.json
import io.ktor.server.application.Application
import io.ktor.server.application.install
import io.ktor.server.engine.embeddedServer
import io.ktor.server.netty.Netty
import io.ktor.server.plugins.contentnegotiation.ContentNegotiation
import io.ktor.server.plugins.cors.routing.CORS
import io.ktor.server.plugins.statuspages.StatusPages
import io.ktor.server.routing.routing
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

  // Read once, up front: CORS and the test-data seed both key off it, and
  // reading it twice invites the two paths to disagree about whether the server
  // is running in dev mode.
  val devMode = System.getenv("DEV_MODE")?.toBoolean() ?: false

  install(ContentNegotiation) {
    json()
  }
  install(Koin) {
    modules(appModule)
  }

  if (devMode) {
    installDevCors()
  }

  val initialSetup by inject<InitialSetup>()
  runBlocking {
    initialSetup.seedInitialData()
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

/**
 * Ports the Flutter dev server is allowed to call from.
 *
 * `./teven dev` pins `--web-port`, so the origin is known and CORS can name it
 * exactly. A small range rather than a single port only so that running
 * `flutter run` by hand on a neighbouring port still works; the backend does
 * not need to change if you pick a different one.
 *
 * Flutter binds the port it is given rather than probing for a free one
 * (`web_device.dart`: `debugPort ?? await findFreePort()`), so this is an
 * enumeration of plausible choices, not a wildcard -- and `allowHost` cannot
 * express "any port": it accepts a wildcard only at the front of a domain, so
 * `localhost:*` is rejected outright.
 */
private val devCorsPorts = 3000..3010

/**
 * Allow the Flutter dev server to call this API cross-origin.
 *
 * Installed **only** when `DEV_MODE` is set, which `docker-compose.yml` wires
 * through and `.env` turns on for local development. The shipped image runs
 * with it unset and serves a bundle from its own origin, where no preflight is
 * ever needed -- so in production this code path does not execute at all.
 *
 * Scope is deliberately limited to `localhost` on http. `anyHost()` would be
 * less code, but it would also let any page the developer visits issue
 * requests to their local backend. The residual exposure is small either way,
 * since auth is a bearer token in an `Authorization` header rather than a
 * cookie: a browser will not attach it to a cross-origin request on its own,
 * so another site cannot act as the signed-in user. It can still reach the
 * unauthenticated endpoints, which is fine for a dev server.
 */
private fun Application.installDevCors() {
  // Installed on the routing root rather than the application. Ktor 3 made the
  // application-scoped `install(CORS)` a deprecation *error* and moved it to
  // `io.ktor.server.plugins.cors.routing`, where it is a route-scoped plugin --
  // so it attaches to a RoutingNode, not to the Application.
  routing {
    install(CORS) {
      devCorsPorts.forEach { port ->
        allowHost("localhost:$port", schemes = listOf("http"))
      }

      // GET, POST and HEAD are allowed by default. The app's updates and
      // deletes are PUT and DELETE.
      allowMethod(HttpMethod.Put)
      allowMethod(HttpMethod.Delete)

      // Both are needed, and omitting Content-Type fails in a way that is easy
      // to misread: `application/json` is a *non-simple* content type, so the
      // browser includes it in `Access-Control-Request-Headers` on the
      // preflight. Ktor rejects the preflight with a bare 403 -- no CORS
      // headers at all -- when it asks for a header that is not allow-listed.
      // A preflight without Content-Type passes, so this only shows up on the
      // JSON endpoints.
      allowHeader(HttpHeaders.ContentType)
      allowHeader(HttpHeaders.Authorization)
    }
  }
}