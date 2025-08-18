package com.teven.auth

import com.teven.core.security.Permission
import io.ktor.server.routing.Route

fun Route.withPermission(permission: Permission, build: Route.() -> Unit): Route {
  val routeWithPermission = createChild(PermissionRouteSelector(permission))
  routeWithPermission.build()
  return routeWithPermission
}
