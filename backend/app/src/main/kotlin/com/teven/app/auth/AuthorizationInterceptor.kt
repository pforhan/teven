package com.teven.app.auth

import com.teven.core.security.Permission
import com.teven.service.role.RoleService
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.createApplicationPlugin
import io.ktor.server.auth.principal
import io.ktor.server.response.respond
import io.ktor.util.AttributeKey

// TODO why is this unused?
val AuthorizationPlugin = createApplicationPlugin("AuthorizationPlugin") {
  val roleService = application.attributes[RoleServiceKey]

  onCall { call ->
    val requiredPermission = call.attributes.getOrNull(RequiredPermissionKey)
    if (requiredPermission != null) {
      val principal = call.principal<UserIdPrincipal>()

      if (principal == null) {
        call.respond(HttpStatusCode.Unauthorized, "Not authenticated")
        return@onCall
      }

      val userRoles = roleService.getRolesForUser(principal.userId)
      val userPermissions = userRoles
        .flatMap { it.permissions }
        // TODO is there a cleaner way to map permissions from strings?
        // TODO handle an invalid permission
        .map { Permission.valueOf(it) }
        .toSet()

      if (!userPermissions.contains(requiredPermission)) {
        call.respond(
          HttpStatusCode.Forbidden,
          "You don't have the required permission to access this resource."
        )
        return@onCall
      }
    }
  }
}

val RequiredPermissionKey = AttributeKey<Permission>("RequiredPermission")
val RoleServiceKey = AttributeKey<RoleService>("RoleServiceKey")
