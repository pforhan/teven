package com.teven.app.user

import com.teven.api.model.user.UpdateUserRequest
import com.teven.core.security.Permission
import com.teven.service.user.UserService
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.call
import io.ktor.server.auth.authenticate
import io.ktor.server.auth.jwt.JWTPrincipal
import io.ktor.server.auth.principal
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.get
import io.ktor.server.routing.put
import io.ktor.server.routing.route
import org.koin.ktor.ext.inject

fun Route.userRoutes() {
  val userService by inject<UserService>()

  route("/api/users") {
    get("/{user_id}") {
      val userId = call.parameters["user_id"]?.toIntOrNull()
      if (userId == null) {
        call.respond(HttpStatusCode.BadRequest, "Invalid user ID")
        return@get
      }

      val principal = call.principal<JWTPrincipal>()
      val requestingUserId = principal?.payload?.getClaim("userId")?.asInt()
      val userPermissions =
        principal?.payload?.getClaim("permissions")?.asList(String::class.java) ?: emptyList()

      if (requestingUserId == userId ||
        userPermissions.contains(Permission.VIEW_USERS_GLOBAL.name) ||
        (userPermissions.contains(Permission.VIEW_USERS_ORGANIZATION.name) && userService.areInSameOrganization(
          requestingUserId,
          userId
        ))
      ) {
        val user = userService.getUserById(userId)
        if (user != null) {
          call.respond(HttpStatusCode.OK, user)
        } else {
          call.respond(HttpStatusCode.NotFound, "User not found")
        }
      } else {
        call.respond(HttpStatusCode.Forbidden, "You don't have permission to view this user.")
      }
    }

    put("/{user_id}") {
      val userId = call.parameters["user_id"]?.toIntOrNull()
      if (userId == null) {
        call.respond(HttpStatusCode.BadRequest, "Invalid user ID")
        return@put
      }

      val principal = call.principal<JWTPrincipal>()
      val requestingUserId = principal?.payload?.getClaim("userId")?.asInt()
      val userPermissions =
        principal?.payload?.getClaim("permissions")?.asList(String::class.java) ?: emptyList()

      if (requestingUserId == userId && userPermissions.contains(Permission.MANAGE_USERS_SELF.name) ||
        userPermissions.contains(Permission.MANAGE_USERS_GLOBAL.name) ||
        (userPermissions.contains(Permission.MANAGE_USERS_ORGANIZATION.name) && userService.areInSameOrganization(
          requestingUserId,
          userId
        ))
      ) {
        val updateUserRequest = call.receive<UpdateUserRequest>()
        val updatedUser = userService.updateUser(userId, updateUserRequest)
        if (updatedUser != null) {
          call.respond(HttpStatusCode.OK, updatedUser)
        } else {
          call.respond(HttpStatusCode.NotFound, "User not found")
        }
      } else {
        call.respond(HttpStatusCode.Forbidden, "You don't have permission to update this user.")
      }
    }
  }
}
