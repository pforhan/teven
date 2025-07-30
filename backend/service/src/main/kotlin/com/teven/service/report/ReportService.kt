
package com.teven.service.report

import com.teven.api.model.report.InventoryUsageReportResponse
import com.teven.api.model.report.StaffHoursReportRequest
import com.teven.api.model.report.StaffHoursReportResponse
import com.teven.data.report.ReportDao

class ReportService(private val reportDao: ReportDao) {
    suspend fun getStaffHoursReport(staffHoursReportRequest: StaffHoursReportRequest): List<StaffHoursReportResponse> {
        return reportDao.getStaffHoursReport(staffHoursReportRequest)
    }

    suspend fun getInventoryUsageReport(): List<InventoryUsageReportResponse> {
        return reportDao.getInventoryUsageReport()
    }
}
