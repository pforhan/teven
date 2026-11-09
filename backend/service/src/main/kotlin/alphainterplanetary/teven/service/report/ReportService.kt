package alphainterplanetary.teven.service.report

import alphainterplanetary.teven.api.model.report.InventoryUsageReportResponse
import alphainterplanetary.teven.api.model.report.StaffHoursReportRequest
import alphainterplanetary.teven.api.model.report.StaffHoursReportResponse
import alphainterplanetary.teven.core.BadRequestException
import alphainterplanetary.teven.data.report.ReportDao
import java.time.ZoneId
import java.time.format.DateTimeParseException

class ReportService(private val reportDao: ReportDao) {
  suspend fun getStaffHoursReport(
    staffHoursReportRequest: StaffHoursReportRequest,
  ): List<StaffHoursReportResponse> {
    if (!ZoneId.getAvailableZoneIds().contains(staffHoursReportRequest.timezone)) {
      throw BadRequestException("Unknown time zone: ${staffHoursReportRequest.timezone}")
    }
    return try {
      reportDao.getStaffHoursReport(staffHoursReportRequest)
    } catch (e: DateTimeParseException) {
      throw BadRequestException("Invalid report date")
    }
  }

  suspend fun getInventoryUsageReport(): List<InventoryUsageReportResponse> {
    return reportDao.getInventoryUsageReport()
  }
}
