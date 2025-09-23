package alphainterplanetary.teven.app

import alphainterplanetary.teven.api.model.auth.LoginRequest
import alphainterplanetary.teven.api.model.common.failure
import alphainterplanetary.teven.api.model.common.success
import alphainterplanetary.teven.core.service.AuthService
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
      val loginResponse = authService.loginUser(loginRequest)
      if (loginResponse != null) {
        call.respond(HttpStatusCode.OK, success(loginResponse))
      } else {
        call.respond(HttpStatusCode.Unauthorized, failure("Invalid credentials"))
      }
    }
  }

  route("/api/invitations") {
    get("/validate") {
      val token = call.request.queryParameters["token"]
      if (token == null) {
        call.respond(HttpStatusCode.BadRequest, failure("Invitation token is missing"))

      } else {
        val invitation = invitationService.validateInvitation(token)
        if (invitation != null) {
          call.respond(
            HttpStatusCode.OK,
            success(mapOf("organizationId" to invitation.organizationId))
          )
        } else {
          call.respond(HttpStatusCode.NotFound, failure("Invalid or expired invitation token"))
        }
      }

    }
  }
}