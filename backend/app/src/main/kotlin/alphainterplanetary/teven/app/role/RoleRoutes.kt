package alphainterplanetary.teven.app.role

import alphainterplanetary.teven.api.model.common.failure
import alphainterplanetary.teven.api.model.common.success
import alphainterplanetary.teven.core.service.RoleService
import io.ktor.http.HttpStatusCode
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.get
import io.ktor.server.routing.route
import org.koin.ktor.ext.inject

fun Route.roleRoutes() {
  val roleService by inject<RoleService>()

  route("/api/roles") {
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
}