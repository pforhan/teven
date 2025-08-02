package com.teven.app.auth

import com.teven.api.model.auth.LoginRequest
import com.teven.api.model.common.StatusResponse
import com.teven.api.model.user.CreateUserRequest
import com.teven.api.model.user.UpdateUserRequest
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
import io.ktor.server.routing.post
import io.ktor.server.routing.put
import io.ktor.server.routing.route
import org.koin.ktor.ext.inject

fun Route.authRoutes() {
  val userService by inject<UserService>()

  route("/api/users") {
    post("/register") {
      val createUserRequest = call.receive<CreateUserRequest>()
      val newUser = userService.createUser(createUserRequest)
      call.respond(HttpStatusCode.Created, newUser)
    }

    post("/login") {
      val loginRequest = call.receive<LoginRequest>()
      val loginResponse = userService.loginUser(loginRequest)
      if (loginResponse != null) {
        call.respond(HttpStatusCode.OK, loginResponse)
      } else {
        call.respond(HttpStatusCode.Unauthorized, StatusResponse("Invalid credentials"))
      }
    }

    authenticate("auth-jwt") {
      get("{user_id}") {
        val principal = call.principal<JWTPrincipal>()
        val authenticatedUserId = principal?.payload?.getClaim("userId")?.asInt()

        val requestedUserId = call.parameters["user_id"]?.toIntOrNull()

        if (authenticatedUserId == null || requestedUserId == null || authenticatedUserId != requestedUserId) {
          call.respond(HttpStatusCode.Forbidden, StatusResponse("Access denied"))
          return@get
        }

        val user = userService.getUserById(authenticatedUserId)
        if (user != null) {
          call.respond(HttpStatusCode.OK, user)
        } else {
          call.respond(HttpStatusCode.NotFound, StatusResponse("User not found"))
        }
      }

      put("{user_id}") {
        val principal = call.principal<JWTPrincipal>()
        val authenticatedUserId = principal?.payload?.getClaim("userId")?.asInt()

        val requestedUserId = call.parameters["user_id"]?.toIntOrNull()

        if (authenticatedUserId == null || requestedUserId == null || authenticatedUserId != requestedUserId) {
          call.respond(HttpStatusCode.Forbidden, StatusResponse("Access denied"))
          return@put
        }

        val updateUserRequest = call.receive<UpdateUserRequest>()
        if (userService.updateUser(authenticatedUserId, updateUserRequest) != null) {
          call.respond(
            HttpStatusCode.OK,
            StatusResponse("User with ID $authenticatedUserId updated")
          )
        } else {
          call.respond(
            HttpStatusCode.NotFound,
            StatusResponse("User not found or no changes applied")
          )
        }
      }

      get("/context") {
        val principal = call.principal<JWTPrincipal>()
        val userId = principal?.payload?.getClaim("userId")?.asInt()

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
    }
  }
}
