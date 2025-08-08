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
      val newUser = userService.createUser(createUserRequest, 0)
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
  }
}
