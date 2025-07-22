
package com.teven.app

import com.teven.app.auth.authRoutes
import com.teven.app.event.eventRoutes
import com.teven.app.customer.customerRoutes
import com.teven.app.inventory.inventoryRoutes
import com.teven.app.report.reportRoutes
import com.teven.app.role.roleRoutes
import io.ktor.server.application.*
import io.ktor.server.routing.*

fun Application.configureRouting() {
    routing {
        authRoutes()
        eventRoutes()
        customerRoutes()
        inventoryRoutes()
        reportRoutes()
        roleRoutes()
    }
}
