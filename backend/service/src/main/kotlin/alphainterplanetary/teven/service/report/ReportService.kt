package alphainterplanetary.teven.service.report

import alphainterplanetary.teven.api.model.report.InventoryUsageReportResponse
import alphainterplanetary.teven.api.model.report.StaffHoursReportRequest
import alphainterplanetary.teven.api.model.report.StaffHoursReportResponse
import alphainterplanetary.teven.data.report.ReportDao

class ReportService(private val reportDao: ReportDao) {
  suspend fun getStaffHoursReport(staffHoursReportRequest: StaffHoursReportRequest): List<StaffHoursReportResponse> {
    return reportDao.getStaffHoursReport(staffHoursReportRequest)
  }

  suspend fun getInventoryUsageReport(): List<InventoryUsageReportResponse> {
    return reportDao.getInventoryUsageReport()
  }
}
