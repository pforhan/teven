package alphainterplanetary.teven.app.organization

import alphainterplanetary.teven.api.model.common.failure
import alphainterplanetary.teven.api.model.common.success
import alphainterplanetary.teven.api.model.organization.CreateOrganizationRequest
import alphainterplanetary.teven.api.model.organization.UpdateOrganizationRequest
import alphainterplanetary.teven.app.requireAuthContext
import alphainterplanetary.teven.auth.withPermission
import alphainterplanetary.teven.core.security.Permission.MANAGE_ORGANIZATIONS_GLOBAL
import alphainterplanetary.teven.core.security.Permission.MANAGE_ORGANIZATION
import alphainterplanetary.teven.core.security.Permission.VIEW_ORGANIZATIONS_GLOBAL
import alphainterplanetary.teven.service.organization.OrganizationService
import io.ktor.http.HttpStatusCode
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

  route("/api/organizations") {
    withPermission(MANAGE_ORGANIZATIONS_GLOBAL, MANAGE_ORGANIZATION) {
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
        val authContext = requireAuthContext()
        if (organizationService.updateOrganization(organizationId, updateOrganizationRequest, authContext.userId)) {
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

    withPermission(VIEW_ORGANIZATIONS_GLOBAL, MANAGE_ORGANIZATION) {
      get {
        val search = call.request.queryParameters["search"]
        val limit = call.request.queryParameters["limit"]?.toIntOrNull()
        val offset = call.request.queryParameters["offset"]?.toLongOrNull()
        val sortBy = call.request.queryParameters["sortBy"]
        val sortOrder = call.request.queryParameters["sortOrder"]

        val organizations = organizationService.getOrganizations(
          search = search,
          limit = limit,
          offset = offset,
          sortBy = sortBy,
          sortOrder = sortOrder
        )
        call.respond(HttpStatusCode.OK, success(organizations))
      }

      get("/{organization_id}") {
        val organizationId = call.parameters["organization_id"]?.toIntOrNull()
        if (organizationId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid organization ID"))
          return@get
        }
        val authContext = requireAuthContext()
        val organization = organizationService.getOrganizationById(organizationId, authContext.userId)
        if (organization != null) {
          call.respond(HttpStatusCode.OK, success(organization))
        } else {
          call.respond(HttpStatusCode.NotFound, failure("Organization not found"))
        }
      }
    }
  }
}