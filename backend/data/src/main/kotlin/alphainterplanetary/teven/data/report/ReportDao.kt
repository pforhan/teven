package alphainterplanetary.teven.data.report

import alphainterplanetary.teven.api.model.report.InventoryUsageReportResponse
import alphainterplanetary.teven.api.model.report.StaffHoursReportRequest
import alphainterplanetary.teven.api.model.report.StaffHoursReportResponse
import alphainterplanetary.teven.data.dbQuery
import alphainterplanetary.teven.data.inventory.InventoryItems
import alphainterplanetary.teven.data.inventory.InventoryUsage
import alphainterplanetary.teven.data.user.Users
import org.jetbrains.exposed.v1.core.ResultRow
import org.jetbrains.exposed.v1.core.and
import org.jetbrains.exposed.v1.core.greaterEq
import org.jetbrains.exposed.v1.core.lessEq
import org.jetbrains.exposed.v1.core.sum
import org.jetbrains.exposed.v1.jdbc.select
import org.jetbrains.exposed.v1.jdbc.selectAll

class ReportDao {
  private fun toStaffHoursReportResponse(row: ResultRow): StaffHoursReportResponse {
    return StaffHoursReportResponse(
      userId = row[StaffHours.userId].value,
      username = row[Users.username],
      displayName = row[Users.displayName],
      totalHoursWorked = row[StaffHours.hoursWorked]
    )
  }

  suspend fun getStaffHoursReport(staffHoursReportRequest: StaffHoursReportRequest): List<StaffHoursReportResponse> =
    dbQuery {
      (StaffHours innerJoin Users)
        .selectAll()
        .where {
          (StaffHours.date greaterEq staffHoursReportRequest.startDate) and
            (StaffHours.date lessEq staffHoursReportRequest.endDate)
        }.map { row: ResultRow -> toStaffHoursReportResponse(row) }
    }

  suspend fun getInventoryUsageReport(): List<InventoryUsageReportResponse> = dbQuery {
    (InventoryUsage innerJoin InventoryItems)
      .select(InventoryItems.id, InventoryItems.name, InventoryUsage.quantityUsed.sum())
      .groupBy(InventoryItems.id, InventoryItems.name)
      .map { row: ResultRow ->
        InventoryUsageReportResponse(
          inventoryId = row[InventoryItems.id].value,
          name = row[InventoryItems.name],
          usageCount = row[InventoryUsage.quantityUsed.sum()] ?: 0
        )
      }
  }
}
