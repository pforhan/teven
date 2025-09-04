package com.teven.app.organization

import com.teven.api.model.common.StatusResponse
import com.teven.api.model.organization.CreateOrganizationRequest
import com.teven.api.model.organization.UpdateOrganizationRequest
import com.teven.auth.withPermission
import com.teven.core.security.Permission
import com.teven.core.service.PermissionService
import com.teven.service.organization.OrganizationService
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.call
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
  val permissionService by inject<PermissionService>()

  route("/api/organizations") {
    withPermission(permissionService, Permission.MANAGE_ORGANIZATIONS_GLOBAL) {
      post {
        val createOrganizationRequest = call.receive<CreateOrganizationRequest>()
        val newOrganization = organizationService.createOrganization(createOrganizationRequest)
        call.respond(HttpStatusCode.Created, newOrganization)
      }

      put("/{organization_id}") {
        val organizationId = call.parameters["organization_id"]?.toIntOrNull()
        if (organizationId == null) {
          call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid organization ID"))
          return@put
        }
        val updateOrganizationRequest = call.receive<UpdateOrganizationRequest>()
        if (organizationService.updateOrganization(organizationId, updateOrganizationRequest)) {
          call.respond(
            HttpStatusCode.OK,
            StatusResponse("Organization with ID $organizationId updated")
          )
        } else {
          call.respond(
            HttpStatusCode.NotFound,
            StatusResponse("Organization not found or no changes applied")
          )
        }
      }

      delete("/{organization_id}") {
        val organizationId = call.parameters["organization_id"]?.toIntOrNull()
        if (organizationId == null) {
          call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid organization ID"))
          return@delete
        }
        if (organizationService.deleteOrganization(organizationId)) {
          call.respond(HttpStatusCode.NoContent)
        } else {
          call.respond(HttpStatusCode.NotFound, StatusResponse("Organization not found"))
        }
      }
    }

    withPermission(permissionService, Permission.VIEW_ORGANIZATIONS_GLOBAL) {
      get {
        val organizations = organizationService.getAllOrganizations()
        call.respond(HttpStatusCode.OK, organizations)
      }

      get("/{organization_id}") {
        val organizationId = call.parameters["organization_id"]?.toIntOrNull()
        if (organizationId == null) {
          call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid organization ID"))
          return@get
        }
        val organization = organizationService.getOrganizationById(organizationId)
        if (organization != null) {
          call.respond(HttpStatusCode.OK, organization)
        } else {
          call.respond(HttpStatusCode.NotFound, StatusResponse("Organization not found"))
        }
      }
    }
  }
}
