package com.teven.app.report

import com.teven.api.model.report.StaffHoursReportRequest
import com.teven.auth.withPermission
import com.teven.core.security.Permission
import com.teven.service.report.ReportService
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.call
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.route
import org.koin.ktor.ext.inject

fun Route.reportRoutes() {
  val reportService by inject<ReportService>()

  route("/api/reports") {
    withPermission(Permission.VIEW_REPORTS_ORGANIZATION) {
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
}
