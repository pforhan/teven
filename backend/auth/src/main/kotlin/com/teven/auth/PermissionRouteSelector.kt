package com.teven.auth

import io.ktor.server.routing.RouteSelector
import io.ktor.server.routing.RouteSelectorEvaluation
import io.ktor.server.routing.RoutingResolveContext

class PermissionRouteSelector : RouteSelector() {
  override suspend fun evaluate(
    context: RoutingResolveContext,
    segmentIndex: Int,
  ): RouteSelectorEvaluation {
    return RouteSelectorEvaluation.Constant
  }
}