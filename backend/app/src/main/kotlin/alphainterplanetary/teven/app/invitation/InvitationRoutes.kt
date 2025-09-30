package alphainterplanetary.teven.app.invitation

import alphainterplanetary.teven.api.model.common.failure
import alphainterplanetary.teven.api.model.common.success
import alphainterplanetary.teven.api.model.invitation.AcceptInvitationRequest
import alphainterplanetary.teven.api.model.invitation.CreateInvitationRequest
import alphainterplanetary.teven.core.security.AuthContext
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.core.user.AcceptInvitationResponse
import alphainterplanetary.teven.core.user.DeleteInvitationStatus.FORBIDDEN
import alphainterplanetary.teven.core.user.DeleteInvitationStatus.NOT_FOUND
import alphainterplanetary.teven.core.user.DeleteInvitationStatus.SUCCESS
import alphainterplanetary.teven.service.invitation.InvitationService
import io.ktor.http.HttpStatusCode
import io.ktor.server.auth.authentication
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.delete
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.route
import org.koin.ktor.ext.inject
import java.time.LocalDateTime

fun Route.publicInvitationRoutes() {
  val invitationService by inject<InvitationService>()

  route("/api/invitations") {
    post("/accept") {
      val authContext = call.authentication.principal<AuthContext>()
      if (authContext != null) {
        call.respond(HttpStatusCode.BadRequest, failure("Cannot accept invitation while logged in."))
        return@post
      }

      val request = call.receive<AcceptInvitationRequest>()
      val response = invitationService.acceptInvitation(request)
      if (response.success) {
        call.respond(HttpStatusCode.Created, success(response.message))
      } else {
        call.respond(HttpStatusCode.BadRequest, failure(response.message ?: "Failed to accept invitation"))
      }
    }
  }
}

fun Route.invitationRoutes() {
  val invitationService by inject<InvitationService>()

  route("/api/invitations") {
    post {
      val request = call.receive<CreateInvitationRequest>()
      val authContext = call.authentication.principal<AuthContext>()!!
      val expiresAt = request.expiresAt?.let { LocalDateTime.parse(it) }

      val organizationId = request.organizationId
      if (organizationId != null && !authContext.hasPermission(Permission.MANAGE_INVITATIONS_GLOBAL)) {
        call.respond(
          HttpStatusCode.Forbidden,
          failure("User does not have permission to create invitations for other organizations")
        )
        return@post
      }

      val invitation = invitationService.generateInvitation(
        organizationId = organizationId ?: authContext.organizationId,
        roleId = request.roleId,
        expiresAt = expiresAt,
        note = request.note,
      )
      call.respond(success(invitation))
    }

    get {
      val authContext = call.authentication.principal<AuthContext>()!!
      val invitations = invitationService.getUnusedInvitations(authContext)
      call.respond(success(invitations))
    }

    delete("/{invitation_id}") {
      val invitationId = call.parameters["invitation_id"]?.toIntOrNull()
      if (invitationId == null) {
        call.respond(HttpStatusCode.BadRequest, failure("Invalid invitation ID"))
        return@delete
      }

      val authContext = call.authentication.principal<AuthContext>()!!
      val result = invitationService.deleteInvitation(invitationId, authContext)

      when (result) {
        SUCCESS -> call.respond(success("Created invitation"))
        NOT_FOUND -> call.respond(
          HttpStatusCode.NotFound,
          failure("Invitation not found")
        )

        FORBIDDEN -> call.respond(
          HttpStatusCode.Forbidden,
          failure("Not authorized to delete this invitation")
        )
      }
    }
  }
}
