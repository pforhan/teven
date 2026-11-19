package alphainterplanetary.teven.app

import alphainterplanetary.teven.api.model.common.failure
import alphainterplanetary.teven.core.BadRequestException
import alphainterplanetary.teven.core.security.AuthContext
import alphainterplanetary.teven.core.security.AuthorizationException
import alphainterplanetary.teven.core.security.UserPermissions
import alphainterplanetary.teven.core.service.PermissionService
import io.ktor.client.HttpClient
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.header
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.serialization.kotlinx.json.json
import io.ktor.server.application.install
import io.ktor.server.auth.Authentication
import io.ktor.server.auth.bearer
import io.ktor.server.plugins.contentnegotiation.ContentNegotiation
import io.ktor.server.plugins.statuspages.StatusPages
import io.ktor.server.response.respond
import io.ktor.server.routing.Routing
import io.ktor.server.routing.routing
import io.ktor.server.testing.ApplicationTestBuilder
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.koin.core.module.Module
import org.koin.dsl.module
import org.koin.ktor.plugin.Koin

val testJson: Json = Json {
  ignoreUnknownKeys = true
  encodeDefaults = true
}

class TestPermissionService(
  private val permissionsByUserId: Map<Int, UserPermissions> = emptyMap(),
) : PermissionService {
  override suspend fun getPermissions(callerId: Int): UserPermissions =
    permissionsByUserId[callerId] ?: UserPermissions(roles = emptyList(), permissions = emptyList())
}

suspend fun ApplicationTestBuilder.routeTestApplication(
  authContext: AuthContext? = null,
  permissionService: PermissionService = TestPermissionService(),
  koinModules: List<Module> = emptyList(),
  configureRouting: Routing.() -> Unit,
  block: suspend ApplicationTestBuilder.(HttpClient) -> Unit,
) {
  application {
    install(ContentNegotiation) { json(testJson) }
    install(StatusPages) {
      exception<AuthorizationException> { call, cause ->
        call.respond(cause.code, failure(cause.message ?: "Authorization error"))
      }
      exception<BadRequestException> { call, cause ->
        call.respond(HttpStatusCode.BadRequest, failure(cause.message ?: "Bad request"))
      }
      exception<io.ktor.server.plugins.BadRequestException> { call, cause ->
        call.respond(HttpStatusCode.BadRequest, failure(cause.message ?: "Bad request"))
      }
    }
    install(Koin) {
      modules(koinModules.ifEmpty { listOf(module { }) })
    }
    install(Authentication) {
      bearer("auth-jwt") {
        realm = "test"
        authenticate { credential ->
          if (credential.token == "test-token") authContext else null
        }
      }
    }
    attributes.put(PermissionService.key, permissionService)

    routing {
      configureRouting()
    }
  }

  val client = createClient { }
  block(client)
}

fun HttpRequestBuilder.asTestUser() {
  header(HttpHeaders.Authorization, "Bearer test-token")
}

fun HttpRequestBuilder.jsonBody(body: String) {
  contentType(ContentType.Application.Json)
  setBody(body)
}

fun JsonObject.string(path: String): String? = this[path]?.jsonPrimitive?.content
fun JsonObject.boolean(path: String): Boolean? = this[path]?.jsonPrimitive?.booleanOrNull
