package alphainterplanetary.teven.app.organization

import alphainterplanetary.teven.api.model.common.failure
import alphainterplanetary.teven.api.model.common.success
import alphainterplanetary.teven.api.model.organization.CreateOrganizationRequest
import alphainterplanetary.teven.api.model.organization.UpdateOrganizationRequest
import alphainterplanetary.teven.app.requireAuthContext
import alphainterplanetary.teven.auth.withPermission
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.core.security.Permission.MANAGE_ORGANIZATIONS_GLOBAL
import alphainterplanetary.teven.core.security.Permission.VIEW_ORGANIZATIONS_GLOBAL
import alphainterplanetary.teven.service.invitation.InvitationService
import alphainterplanetary.teven.service.organization.OrganizationService
import io.ktor.http.HttpStatusCode
import io.ktor.server.plugins.origin
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.delete
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.put
import io.ktor.server.routing.route
import org.koin.ktor.ext.inject

fun Route.organizationRoutes() {
  val organizationService by inject<OrganizationService>()
  val invitationService by inject<InvitationService>()

  route("/api/organizations") {
    withPermission(MANAGE_ORGANIZATIONS_GLOBAL) {
      post {
        val createOrganizationRequest = call.receive<CreateOrganizationRequest>()
        val newOrganization = organizationService.createOrganization(createOrganizationRequest)
        call.respond(HttpStatusCode.Created, success(newOrganization))
      }

      put("/{organization_id}") {
        val organizationId = call.parameters["organization_id"]?.toIntOrNull()
        if (organizationId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid organization ID"))
          return@put
        }
        val updateOrganizationRequest = call.receive<UpdateOrganizationRequest>()
        if (organizationService.updateOrganization(organizationId, updateOrganizationRequest)) {
          call.respond(
            HttpStatusCode.OK,
            success("Organization with ID $organizationId updated")
          )
        } else {
          call.respond(
            HttpStatusCode.NotFound,
            failure("Organization not found or no changes applied")
          )
        }
      }

      delete("/{organization_id}") {
        val organizationId = call.parameters["organization_id"]?.toIntOrNull()
        if (organizationId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid organization ID"))
          return@delete
        }
        if (organizationService.deleteOrganization(organizationId)) {
          call.respond(HttpStatusCode.NoContent)
        } else {
          call.respond(HttpStatusCode.NotFound, failure("Organization not found"))
        }
      }
    }

    withPermission(Permission.MANAGE_INVITATIONS_ORGANIZATION) {
      post("{organization_id}/invitations") {
        val authContext = requireAuthContext()
        val inviteOrganizationId = call.parameters["organization_id"]?.toIntOrNull()
        val roleId = call.request.queryParameters["roleId"]?.toIntOrNull()

        if (inviteOrganizationId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid organization ID"))
          return@post
        }
        if (roleId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Role ID is required"))
          return@post
        }

        // Ensure the user has permission for this organization
        if (!authContext.hasPermission(MANAGE_ORGANIZATIONS_GLOBAL) && authContext.organizationId != inviteOrganizationId) {
          call.respond(HttpStatusCode.Forbidden, failure("Not authorized to create invitations for this organization"))
          return@post
        }

        val invitation = invitationService.generateInvitation(inviteOrganizationId, roleId)
        val invitationUrl = "${call.request.origin.scheme}://${call.request.origin.serverHost}:${call.request.origin.serverPort}/register?token=${invitation.token}"
        call.respond(HttpStatusCode.Created, success(mapOf("invitationUrl" to invitationUrl)))
      }
    }

    withPermission(VIEW_ORGANIZATIONS_GLOBAL) {
      get {
        val organizations = organizationService.getAllOrganizations()
        call.respond(HttpStatusCode.OK, success(organizations))
      }

      get("/{organization_id}") {
        val organizationId = call.parameters["organization_id"]?.toIntOrNull()
        if (organizationId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid organization ID"))
          return@get
        }
        val organization = organizationService.getOrganizationById(organizationId)
        if (organization != null) {
          call.respond(HttpStatusCode.OK, success(organization))
        } else {
          call.respond(HttpStatusCode.NotFound, failure("Organization not found"))
        }
      }
    }
  }
}