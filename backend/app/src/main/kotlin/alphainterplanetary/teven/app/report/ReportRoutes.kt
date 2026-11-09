package alphainterplanetary.teven.app.report

import alphainterplanetary.teven.api.model.common.success
import alphainterplanetary.teven.api.model.report.StaffHoursReportRequest
import alphainterplanetary.teven.app.requireAuthContext
import alphainterplanetary.teven.auth.withPermission
import alphainterplanetary.teven.core.security.Permission.VIEW_REPORTS_GLOBAL
import alphainterplanetary.teven.core.security.Permission.VIEW_REPORTS_ORGANIZATION
import alphainterplanetary.teven.service.report.ReportService
import io.ktor.http.HttpStatusCode
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
    withPermission(VIEW_REPORTS_ORGANIZATION, VIEW_REPORTS_GLOBAL) {
      post("/staff_hours") {
        val authContext = requireAuthContext()
        val staffHoursReportRequest = call.receive<StaffHoursReportRequest>()
        val report = reportService.getStaffHoursReport(authContext, staffHoursReportRequest)
        call.respond(HttpStatusCode.OK, success(report))
      }

      get("/inventory_usage") {
        val authContext = requireAuthContext()
        val report = reportService.getInventoryUsageReport(authContext)
        call.respond(HttpStatusCode.OK, success(report))
      }
    }
  }
}