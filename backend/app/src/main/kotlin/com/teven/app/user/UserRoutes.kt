package com.teven.app.user

import com.teven.api.model.common.StatusResponse
import com.teven.api.model.user.CreateUserRequest
import com.teven.core.service.UserService
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.call
import io.ktor.server.auth.jwt.JWTPrincipal
import io.ktor.server.auth.principal
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.route
import org.koin.ktor.ext.inject

fun Route.userRoutes() {
  val userService by inject<UserService>()

  route("/api/users") {
    post {
      val principal = call.principal<JWTPrincipal>()
      val callerId = principal?.payload?.getClaim("userId")?.asInt()
      if (callerId == null) {
        call.respond(HttpStatusCode.Unauthorized, StatusResponse("User ID not found in token"))
        return@post
      }

      val createUserRequest = call.receive<CreateUserRequest>()
      try {
        val newUser = userService.createUser(createUserRequest, callerId)
        call.respond(HttpStatusCode.Created, newUser)
      } catch (e: SecurityException) {
        call.respond(HttpStatusCode.Forbidden, StatusResponse(e.message ?: "Permission denied"))
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