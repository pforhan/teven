package alphainterplanetary.teven.app

import alphainterplanetary.teven.api.model.common.failure
import alphainterplanetary.teven.app.invitation.invitationRoutes
import alphainterplanetary.teven.app.customer.customerRoutes
import alphainterplanetary.teven.app.event.eventRoutes
import alphainterplanetary.teven.app.inventory.inventoryRoutes
import alphainterplanetary.teven.app.organization.organizationRoutes
import alphainterplanetary.teven.app.report.reportRoutes
import alphainterplanetary.teven.app.role.roleRoutes
import alphainterplanetary.teven.app.user.userRoutes
import alphainterplanetary.teven.core.security.AuthContext
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.Application
import io.ktor.server.application.call
import io.ktor.server.auth.authenticate
import io.ktor.server.auth.principal
import io.ktor.server.http.content.default
import io.ktor.server.http.content.staticResources
import io.ktor.server.response.respond
import io.ktor.server.routing.*

fun Application.configureRouting() {
  routing {
    authRoutes()
    authenticate("auth-jwt") {
      userRoutes()
      eventRoutes()
      customerRoutes()
      inventoryRoutes()
      reportRoutes()
      roleRoutes()
      organizationRoutes()
      invitationRoutes()
    }

    // Catch-all for unmatched API routes
    route("/api") {
      get("/{...}") {
        call.respond(HttpStatusCode.NotFound, failure("API endpoint not found"))
      }
      post("/{...}") {
        call.respond(HttpStatusCode.NotFound, failure("API endpoint not found"))
      }
      put("/{...}") {
        call.respond(HttpStatusCode.NotFound, failure("API endpoint not found"))
      }
      delete("/{...}") {
        call.respond(HttpStatusCode.NotFound, failure("API endpoint not found"))
      }
    }

    // Serve static content last, so API routes are matched first
    staticResources("/", "static") {
      default("index.html")
    }
  }
}

fun RoutingContext.maybeAuthContext(): AuthContext? = call.principal<AuthContext>()
fun RoutingContext.requireAuthContext(): AuthContext = maybeAuthContext()!!
