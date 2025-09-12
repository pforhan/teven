package com.teven.app

import com.teven.api.model.common.failure
import com.teven.app.customer.customerRoutes
import com.teven.app.event.eventRoutes
import com.teven.app.inventory.inventoryRoutes
import com.teven.app.organization.organizationRoutes
import com.teven.app.report.reportRoutes
import com.teven.app.role.roleRoutes
import com.teven.app.user.userRoutes
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.Application
import io.ktor.server.application.call
import io.ktor.server.auth.authenticate
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