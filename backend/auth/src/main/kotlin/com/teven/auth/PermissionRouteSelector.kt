package com.teven.auth

import com.teven.core.security.Permission
import io.ktor.server.routing.RouteSelector
import io.ktor.server.routing.RouteSelectorEvaluation
import io.ktor.server.routing.RoutingResolveContext

data class PermissionRouteSelector(val permission: Permission) : RouteSelector() {
  override fun evaluate(
      context: RoutingResolveContext,
      segmentIndex: Int,
  ): RouteSelectorEvaluation {
    return RouteSelectorEvaluation.Constant
  }

  override fun toString(): String = "(permission ${permission.name})"
}
