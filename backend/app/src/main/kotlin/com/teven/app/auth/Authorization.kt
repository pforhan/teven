package com.teven.app.auth

import com.teven.core.security.Permission
import com.teven.service.role.RoleService
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.createRouteScopedPlugin
import io.ktor.server.auth.AuthenticationChecked
import io.ktor.server.auth.jwt.JWTPrincipal
import io.ktor.server.auth.principal

class AuthorizationException(val code: HttpStatusCode, message: String) : Exception(message)

fun createAuthorizationPlugin(roleService: RoleService) = createRouteScopedPlugin(
  name = "AuthorizationPlugin",
  createConfiguration = ::PluginConfiguration
) {
  on(AuthenticationChecked) { call ->
    val requiredPermission = pluginConfig.requiredPermission
    if (requiredPermission != null) {
      val principal = call.principal<JWTPrincipal>()
      if (principal == null) {
        throw AuthorizationException(HttpStatusCode.Unauthorized, "Not authenticated")
      }

      val userId = principal.payload.getClaim("userId").asInt()
      if (userId == null) {
        throw AuthorizationException(HttpStatusCode.BadRequest, "Invalid token: userId missing")
      }

      val userRoles = roleService.getRolesForUser(userId)
      val userPermissions = userRoles.flatMap { it.permissions }.toSet()

      if (requiredPermission.name !in userPermissions) {
        throw AuthorizationException(
          HttpStatusCode.Forbidden,
          "Missing required permission: ${requiredPermission.name}"
        )
      }
    }
  }
}

class PluginConfiguration {
  var requiredPermission: Permission? = null
}
