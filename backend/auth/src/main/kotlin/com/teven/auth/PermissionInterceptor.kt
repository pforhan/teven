package com.teven.auth

import com.teven.core.security.Permission
import com.teven.core.service.PermissionService
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.ApplicationCallPipeline
import io.ktor.server.application.call
import io.ktor.server.auth.jwt.JWTPrincipal
import io.ktor.server.auth.principal
import io.ktor.server.response.respond
import io.ktor.server.routing.Route

fun Route.withPermission(permissionService: PermissionService, vararg permissions: Permission, build: Route.() -> Unit): Route {
    val routeWithPermissions = createChild(PermissionRouteSelector())
    routeWithPermissions.intercept(ApplicationCallPipeline.Call) { 
        val principal = call.principal<JWTPrincipal>()
        val callerId = principal?.payload?.getClaim("userId")?.asInt()

        if (callerId == null) {
            call.respond(HttpStatusCode.Unauthorized, "User ID not found in token")
            return@intercept
        }

        val userPermissions = permissionService.getPermissions(callerId)

        if (!userPermissions.hasAnyPermissions(*permissions)) {
            call.respond(HttpStatusCode.Forbidden, "User does not have the required permission")
            return@intercept
        }

        proceed()
    }

    build(routeWithPermissions)
    return routeWithPermissions
}
