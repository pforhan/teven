package alphainterplanetary.teven.app

import alphainterplanetary.teven.api.model.auth.LoginRequest
import alphainterplanetary.teven.api.model.common.failure
import alphainterplanetary.teven.api.model.common.success
import alphainterplanetary.teven.core.service.AuthService
import alphainterplanetary.teven.core.service.LoginResult
import alphainterplanetary.teven.service.invitation.InvitationService
import io.ktor.http.HttpStatusCode
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.route
import org.koin.ktor.ext.inject

fun Route.authRoutes() {
  val authService by inject<AuthService>()
  val invitationService by inject<InvitationService>()

  route("/api/users") {

    post("/login") {
      val loginRequest = call.receive<LoginRequest>()
      call.application.environment.log.info("Received login request for: ${loginRequest.username}")
      
      when (val result = authService.loginUser(loginRequest)) {
        is LoginResult.Success -> {
          call.respond(HttpStatusCode.OK, success(result.response))
        }
        is LoginResult.UserNotFound, is LoginResult.InvalidPassword -> {
          call.application.environment.log.warn("Login failed (${result::class.simpleName}) for: ${loginRequest.username}")
          call.respond(HttpStatusCode.Unauthorized, failure("Invalid credentials"))
        }
      }
    }
  }
}