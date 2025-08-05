package com.teven.app.auth

import com.teven.core.security.Permission
import com.teven.service.role.RoleService
import io.ktor.server.application.install
import io.ktor.server.routing.Route
import org.koin.ktor.ext.inject

fun Route.withPermission(permission: Permission, build: Route.() -> Unit): Route {
  val routeWithPermission = createChild(PermissionRouteSelector(permission))
  routeWithPermission.build()
  return routeWithPermission
}
