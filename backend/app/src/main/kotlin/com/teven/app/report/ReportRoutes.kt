
package com.teven.app.report

import com.teven.api.model.report.StaffHoursReportRequest
import com.teven.service.report.ReportService
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import org.koin.ktor.ext.inject

fun Route.reportRoutes() {
    val reportService by inject<ReportService>()

    route("/api/reports") {
        post("/staff_hours") {
            val staffHoursReportRequest = call.receive<StaffHoursReportRequest>()
            val report = reportService.getStaffHoursReport(staffHoursReportRequest)
            call.respond(HttpStatusCode.OK, report)
        }

        get("/inventory_usage") {
            val report = reportService.getInventoryUsageReport()
            call.respond(HttpStatusCode.OK, report)
        }
    }
}
