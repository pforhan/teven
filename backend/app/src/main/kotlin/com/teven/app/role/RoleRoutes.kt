package com.teven.app.role

import com.teven.api.model.common.failure
import com.teven.api.model.common.success
import com.teven.api.model.role.CreateRoleRequest
import com.teven.api.model.role.UpdateRoleRequest
import com.teven.auth.withPermission
import com.teven.core.security.Permission.MANAGE_ROLES_GLOBAL
import com.teven.core.service.RoleService
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.*
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

  route("/api/roles") {
    withPermission(MANAGE_ROLES_GLOBAL) {
      post {
        val createRoleRequest = call.receive<CreateRoleRequest>()
        val newRole = roleService.createRole(createRoleRequest)
        call.respond(HttpStatusCode.Created, success(newRole))
      }

      put("/{role_id}") {
        val roleId = call.parameters["role_id"]?.toIntOrNull()
        if (roleId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid role ID"))
          return@put
        }
        val updateRoleRequest = call.receive<UpdateRoleRequest>()
        if (roleService.updateRole(roleId, updateRoleRequest)) {
          call.respond(HttpStatusCode.OK, success("Role with ID $roleId updated"))
        } else {
          call.respond(
            HttpStatusCode.NotFound,
            failure("Role not found or no changes applied")
          )
        }
      }

      delete("/{role_id}") {
        val roleId = call.parameters["role_id"]?.toIntOrNull()
        if (roleId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid role ID"))
          return@delete
        }
        if (roleService.deleteRole(roleId)) {
          call.respond(HttpStatusCode.NoContent)
        } else {
          call.respond(HttpStatusCode.NotFound, failure("Role not found"))
        }
      }
    }

    get {
      val roles = roleService.getAllRoles()
      call.respond(HttpStatusCode.OK, success(roles))
    }

    get("/{role_id}") {
      val roleId = call.parameters["role_id"]?.toIntOrNull()
      if (roleId == null) {
        call.respond(HttpStatusCode.BadRequest, failure("Invalid role ID"))
        return@get
      }
      val role = roleService.getRoleById(roleId)
      if (role != null) {
        call.respond(HttpStatusCode.OK, success(role))
      } else {
        call.respond(HttpStatusCode.NotFound, failure("Role not found"))
      }
    }
  }

  route("/api/users/{user_id}/roles") {
    withPermission(MANAGE_ROLES_GLOBAL) {
      post("/{role_id}") {
        val userId = call.parameters["user_id"]?.toIntOrNull()
        val roleId = call.parameters["role_id"]?.toIntOrNull()
        if (userId == null || roleId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid user ID or role ID"))
          return@post
        }
        if (roleService.assignRoleToUser(userId, roleId)) {
          call.respond(HttpStatusCode.OK, success("OK"))
        } else {
          call.respond(
            HttpStatusCode.InternalServerError,
            failure("Failed to assign role")
          )
        }
      }

      delete("/{role_id}") {
        val userId = call.parameters["user_id"]?.toIntOrNull()
        val roleId = call.parameters["role_id"]?.toIntOrNull()
        if (userId == null || roleId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid user ID or role ID"))
          return@delete
        }
        if (roleService.removeRoleFromUser(userId, roleId)) {
          call.respond(HttpStatusCode.OK, success("OK"))
        } else {
          call.respond(
            HttpStatusCode.InternalServerError,
            failure("Failed to remove role")
          )
        }
      }
    }
  }
}