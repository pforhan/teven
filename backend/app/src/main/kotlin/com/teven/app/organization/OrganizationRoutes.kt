package com.teven.app.organization

import com.teven.api.model.common.StatusResponse
import com.teven.api.model.organization.CreateOrganizationRequest
import com.teven.api.model.organization.UpdateOrganizationRequest
import com.teven.service.organization.OrganizationService
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.auth.jwt.JWTPrincipal
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import org.koin.ktor.ext.inject

fun Route.organizationRoutes() {
    val organizationService by inject<OrganizationService>()

    authenticate("auth-jwt") {
        route("/api/organizations") {
            // SuperAdmin only routes
            post {
                val principal = call.principal<JWTPrincipal>()
                val userRole = principal?.payload?.getClaim("role")?.asString()
                if (userRole != "superadmin") {
                    call.respond(HttpStatusCode.Forbidden, StatusResponse("Access denied: SuperAdmin role required"))
                    return@post
                }
                val createOrganizationRequest = call.receive<CreateOrganizationRequest>()
                val newOrganization = organizationService.createOrganization(createOrganizationRequest)
                call.respond(HttpStatusCode.Created, newOrganization)
            }

            get {
                val principal = call.principal<JWTPrincipal>()
                val userRole = principal?.payload?.getClaim("role")?.asString()
                if (userRole != "superadmin") {
                    call.respond(HttpStatusCode.Forbidden, StatusResponse("Access denied: SuperAdmin role required"))
                    return@get
                }
                val organizations = organizationService.getAllOrganizations()
                call.respond(HttpStatusCode.OK, organizations)
            }

            get("/{organization_id}") {
                val principal = call.principal<JWTPrincipal>()
                val userRole = principal?.payload?.getClaim("role")?.asString()
                if (userRole != "superadmin") {
                    call.respond(HttpStatusCode.Forbidden, StatusResponse("Access denied: SuperAdmin role required"))
                    return@get
                }
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

            put("/{organization_id}") {
                val principal = call.principal<JWTPrincipal>()
                val userRole = principal?.payload?.getClaim("role")?.asString()
                if (userRole != "superadmin") {
                    call.respond(HttpStatusCode.Forbidden, StatusResponse("Access denied: SuperAdmin role required"))
                    return@put
                }
                val organizationId = call.parameters["organization_id"]?.toIntOrNull()
                if (organizationId == null) {
                    call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid organization ID"))
                    return@put
                }
                val updateOrganizationRequest = call.receive<UpdateOrganizationRequest>()
                if (organizationService.updateOrganization(organizationId, updateOrganizationRequest)) {
                    call.respond(HttpStatusCode.OK, StatusResponse("Organization with ID $organizationId updated"))
                } else {
                    call.respond(HttpStatusCode.NotFound, StatusResponse("Organization not found or no changes applied"))
                }
            }

            delete("/{organization_id}") {
                val principal = call.principal<JWTPrincipal>()
                val userRole = principal?.payload?.getClaim("role")?.asString()
                if (userRole != "superadmin") {
                    call.respond(HttpStatusCode.Forbidden, StatusResponse("Access denied: SuperAdmin role required"))
                    return@delete
                }
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
    }
}
