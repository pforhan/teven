package com.teven.auth

import com.teven.core.security.Permission
import com.teven.core.security.UserPrincipal
import com.teven.core.service.PermissionService
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.createRouteScopedPlugin
import io.ktor.server.auth.authentication
import io.ktor.server.response.respond

val AuthorizationPlugin = createRouteScopedPlugin(
  name = "AuthorizationPlugin",
  createConfiguration = { mutableSetOf<Permission>() }
) {
  val permissionService = application.attributes[PermissionService.key]

  pluginConfig.forEach { permission ->
    onCall { call ->
      val principal = call.authentication.principal<UserPrincipal>()
      val callerId = principal?.userId

      if (callerId == null) {
        call.respond(HttpStatusCode.Unauthorized, "User ID not found in token")
        return@onCall
      }

      val userPermissions = permissionService.getPermissions(callerId)

      if (!userPermissions.hasPermission(permission)) {
        call.respond(HttpStatusCode.Forbidden, "User does not have the required permission")
        return@onCall
      }
    }
  }
}
