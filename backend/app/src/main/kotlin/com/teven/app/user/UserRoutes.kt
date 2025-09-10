package com.teven.app.user

import com.teven.api.model.common.StatusResponse
import com.teven.api.model.user.CreateUserRequest
import com.teven.auth.UserIdPrincipal
import com.teven.auth.withPermission
import com.teven.core.security.Permission.MANAGE_USERS_ORGANIZATION
import com.teven.core.security.Permission.VIEW_USERS_ORGANIZATION
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
        call.respond(HttpStatusCode.Created, newUser)
      }
    }

    withPermission(VIEW_USERS_ORGANIZATION) {
      get {
        val principal = call.principal<UserIdPrincipal>()
        val callerId = principal?.userId ?: return@get
        val users = userService.getAllUsers(callerId)
        call.respond(HttpStatusCode.OK, users)
      }
    }

    get("/context") {
      val principal = call.principal<UserIdPrincipal>()
      val userId = principal?.userId

      if (userId == null) {
        call.respond(HttpStatusCode.Unauthorized, StatusResponse("User ID not found in token"))
        return@get
      }

      val userContext = userService.getUserContext(userId)
      if (userContext != null) {
        call.respond(HttpStatusCode.OK, userContext)
      } else {
        call.respond(HttpStatusCode.NotFound, StatusResponse("User context not found"))
      }
    }

    withPermission(VIEW_USERS_ORGANIZATION) {
      get("/{userId}") {
        val userId = call.parameters["userId"]?.toIntOrNull() ?: return@get
        val user = userService.getUserById(userId)
        if (user != null) {
          call.respond(HttpStatusCode.OK, user)
        } else {
          call.respond(HttpStatusCode.NotFound, StatusResponse("User not found"))
        }
      }
    }

    withPermission(MANAGE_USERS_ORGANIZATION) {
      put("/{userId}") {
        val userId = call.parameters["userId"]?.toIntOrNull() ?: return@put
        val updateUserRequest = call.receive<com.teven.api.model.user.UpdateUserRequest>()
        val updatedUser = userService.updateUser(userId, updateUserRequest)
        if (updatedUser != null) {
          call.respond(HttpStatusCode.OK, updatedUser)
        } else {
          call.respond(HttpStatusCode.NotFound, StatusResponse("User not found"))
        }
      }
    }
  }
}
