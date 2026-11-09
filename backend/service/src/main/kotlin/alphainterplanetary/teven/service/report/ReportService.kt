package alphainterplanetary.teven.service.report

import alphainterplanetary.teven.api.model.report.InventoryUsageReportResponse
import alphainterplanetary.teven.api.model.report.StaffHoursReportRequest
import alphainterplanetary.teven.api.model.report.StaffHoursReportResponse
import alphainterplanetary.teven.core.BadRequestException
import alphainterplanetary.teven.core.security.AuthContext
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.data.report.ReportDao
import java.time.ZoneId
import java.time.format.DateTimeParseException

class ReportService(private val reportDao: ReportDao) {
  suspend fun getStaffHoursReport(
    authContext: AuthContext,
    staffHoursReportRequest: StaffHoursReportRequest,
  ): List<StaffHoursReportResponse> {
    if (!ZoneId.getAvailableZoneIds().contains(staffHoursReportRequest.timezone)) {
      throw BadRequestException("Unknown time zone: ${staffHoursReportRequest.timezone}")
    }
    val organizationId = if (authContext.hasPermission(Permission.VIEW_REPORTS_GLOBAL)) {
      null
    } else {
      authContext.organizationId
    }
    return try {
      reportDao.getStaffHoursReport(staffHoursReportRequest, organizationId)
    } catch (e: DateTimeParseException) {
      throw BadRequestException("Invalid report date")
    }
  }

  suspend fun getInventoryUsageReport(authContext: AuthContext): List<InventoryUsageReportResponse> {
    val organizationId = if (authContext.hasPermission(Permission.VIEW_REPORTS_GLOBAL)) {
      null
    } else {
      authContext.organizationId
    }
    return reportDao.getInventoryUsageReport(organizationId)
  }
}
