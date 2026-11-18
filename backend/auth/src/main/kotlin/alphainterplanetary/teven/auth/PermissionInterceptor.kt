package alphainterplanetary.teven.auth

import alphainterplanetary.teven.api.model.common.failure
import alphainterplanetary.teven.core.security.AuthContext
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.core.service.PermissionService
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.ApplicationCallPipeline
import io.ktor.server.application.call
import io.ktor.server.auth.authenticate
import io.ktor.server.auth.principal
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.intercept

fun Route.withPermission(vararg permissions: Permission, build: Route.() -> Unit): Route {
  val routeWithPermissions = createChild(PermissionRouteSelector())
  val required = permissions.toSet()

  routeWithPermissions.authenticate("auth-jwt") {
    intercept(ApplicationCallPipeline.Call) {
      val principal = call.principal<AuthContext>()
      val callerId = principal?.userId

      if (callerId == null) {
        call.respond(HttpStatusCode.Unauthorized, failure("User ID not found in token"))
        finish()
        return@intercept
      }

      val permissionService = call.application.attributes[PermissionService.key]
      val userPermissions = permissionService.getPermissions(callerId)
      val authorized = required.isEmpty() || required.any { userPermissions.hasPermission(it) }

      if (!authorized) {
        call.respond(
          HttpStatusCode.Forbidden,
          failure("User does not have the required permission"),
        )
        finish()
        return@intercept
      }

      proceed()
    }
    this.build()
  }

  return routeWithPermissions
}
