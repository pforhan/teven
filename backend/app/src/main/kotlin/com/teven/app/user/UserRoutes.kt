package com.teven.app.user

import com.teven.api.model.common.failure
import com.teven.api.model.common.success
import com.teven.api.model.user.CreateUserRequest
import com.teven.auth.withPermission
import com.teven.core.security.Permission.MANAGE_USERS_ORGANIZATION
import com.teven.core.security.Permission.VIEW_USERS_ORGANIZATION
import com.teven.core.security.UserPrincipal
import com.teven.core.service.UserService
import io.ktor.http.HttpStatusCode
import io.ktor.server.auth.principal
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.put
import io.ktor.server.routing.route
import org.koin.ktor.ext.inject

fun Route.userRoutes() {
  val userService by inject<UserService>()

  route("/api/users") {
    withPermission(MANAGE_USERS_ORGANIZATION) {
      post {
        val createUserRequest = call.receive<CreateUserRequest>()
        val newUser = userService.createUser(createUserRequest)
        call.respond(HttpStatusCode.Created, success(newUser))
      }
    }

    withPermission(VIEW_USERS_ORGANIZATION) {
      get {
        val principal = call.principal<UserPrincipal>()
        val callerId = principal?.userId ?: return@get
        val users = userService.getAllUsers(callerId)
        call.respond(HttpStatusCode.OK, success(users))
      }
    }

    get("/context") {
      val principal = call.principal<UserPrincipal>()
      val userId = principal?.userId

      if (userId == null) {
        call.respond(HttpStatusCode.Unauthorized, failure("User ID not found in token"))
        return@get
      }

      call.respond(HttpStatusCode.OK, success(userService.getUserContext(userId)))
    }

    withPermission(VIEW_USERS_ORGANIZATION) {
      get("/{userId}") {
        val userId = call.parameters["userId"]?.toIntOrNull() ?: return@get
        val user = userService.getUserById(userId)
        if (user != null) {
          call.respond(HttpStatusCode.OK, success(user))
        } else {
          call.respond(HttpStatusCode.NotFound, failure("User not found"))
        }
      }
    }

    withPermission(MANAGE_USERS_ORGANIZATION) {
      put("/{userId}") {
        val userId = call.parameters["userId"]?.toIntOrNull() ?: return@put
        val updateUserRequest = call.receive<com.teven.api.model.user.UpdateUserRequest>()
        val updatedUser = userService.updateUser(userId, updateUserRequest)
        if (updatedUser != null) {
          call.respond(HttpStatusCode.OK, success(updatedUser))
        } else {
          call.respond(HttpStatusCode.NotFound, failure("User not found"))
        }
      }
    }
  }
}