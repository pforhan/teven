package com.teven.app.role

import com.teven.api.model.common.StatusResponse
import com.teven.api.model.role.CreateRoleRequest
import com.teven.api.model.role.UpdateRoleRequest
import com.teven.app.auth.withPermission
import com.teven.core.security.Permission
import com.teven.service.role.RoleService
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.call
import io.ktor.server.auth.authenticate
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.delete
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.put
import io.ktor.server.routing.route
import org.koin.ktor.ext.inject

fun Route.roleRoutes() {
  val roleService by inject<RoleService>()

  authenticate("auth-jwt") {
    route("/api/roles") {
      withPermission(Permission.MANAGE_ROLES_GLOBAL) {
        post {
          val createRoleRequest = call.receive<CreateRoleRequest>()
          val newRole = roleService.createRole(createRoleRequest)
          call.respond(HttpStatusCode.Created, newRole)
        }

        put("/{role_id}") {
          val roleId = call.parameters["role_id"]?.toIntOrNull()
          if (roleId == null) {
            call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid role ID"))
            return@put
          }
          val updateRoleRequest = call.receive<UpdateRoleRequest>()
          if (roleService.updateRole(roleId, updateRoleRequest)) {
            call.respond(HttpStatusCode.OK, StatusResponse("Role with ID $roleId updated"))
          } else {
            call.respond(
              HttpStatusCode.NotFound,
              StatusResponse("Role not found or no changes applied")
            )
          }
        }

        delete("/{role_id}") {
          val roleId = call.parameters["role_id"]?.toIntOrNull()
          if (roleId == null) {
            call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid role ID"))
            return@delete
          }
          if (roleService.deleteRole(roleId)) {
            call.respond(HttpStatusCode.NoContent)
          } else {
            call.respond(HttpStatusCode.NotFound, StatusResponse("Role not found"))
          }
        }
      }

      get {
        val roles = roleService.getAllRoles()
        call.respond(HttpStatusCode.OK, roles)
      }

      get("/{role_id}") {
        val roleId = call.parameters["role_id"]?.toIntOrNull()
        if (roleId == null) {
          call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid role ID"))
          return@get
        }
        val role = roleService.getRoleById(roleId)
        if (role != null) {
          call.respond(HttpStatusCode.OK, role)
        } else {
          call.respond(HttpStatusCode.NotFound, StatusResponse("Role not found"))
        }
      }
    }

    route("/api/users/{user_id}/roles") {
      withPermission(Permission.MANAGE_ROLES_GLOBAL) {
        post("/{role_id}") {
          val userId = call.parameters["user_id"]?.toIntOrNull()
          val roleId = call.parameters["role_id"]?.toIntOrNull()
          if (userId == null || roleId == null) {
            call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid user ID or role ID"))
            return@post
          }
          if (roleService.assignRoleToUser(userId, roleId)) {
            call.respond(HttpStatusCode.OK, StatusResponse("OK"))
          } else {
            call.respond(
              HttpStatusCode.InternalServerError,
              StatusResponse("Failed to assign role")
            )
          }
        }

        delete("/{role_id}") {
          val userId = call.parameters["user_id"]?.toIntOrNull()
          val roleId = call.parameters["role_id"]?.toIntOrNull()
          if (userId == null || roleId == null) {
            call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid user ID or role ID"))
            return@delete
          }
          if (roleService.removeRoleFromUser(userId, roleId)) {
            call.respond(HttpStatusCode.OK, StatusResponse("OK"))
          } else {
            call.respond(
              HttpStatusCode.InternalServerError,
              StatusResponse("Failed to remove role")
            )
          }
        }
      }
    }
  }
}
