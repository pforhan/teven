package com.teven.auth

import com.teven.core.security.Permission
import io.ktor.server.auth.authenticate
import io.ktor.server.routing.Route

fun Route.withPermission(vararg permissions: Permission, build: Route.() -> Unit): Route {
  val routeWithPermissions = createChild(PermissionRouteSelector())
  // This has to run after the AuthorizationPlugin so that credentials will be present.
  routeWithPermissions.authenticate("auth-jwt") {
    install(AuthorizationPlugin) {
      permissions.forEach { add(it) }
    }
    build(routeWithPermissions)
  }
  return routeWithPermissions
}
