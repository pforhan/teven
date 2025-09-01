package com.teven.app

import com.teven.api.model.auth.LoginRequest
import com.teven.api.model.common.StatusResponse
import com.teven.core.service.AuthService
import com.teven.core.service.UserService
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.call
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.post
import io.ktor.server.routing.route
import org.koin.ktor.ext.inject

fun Route.authRoutes() {
  val authService by inject<AuthService>()

  route("/api/users") {

    post("/login") {
      val loginRequest = call.receive<LoginRequest>()
      val loginResponse = authService.loginUser(loginRequest)
      if (loginResponse != null) {
        call.respond(HttpStatusCode.OK, loginResponse)
      } else {
        call.respond(HttpStatusCode.Unauthorized, StatusResponse("Invalid credentials"))
      }
    }
  }
}
