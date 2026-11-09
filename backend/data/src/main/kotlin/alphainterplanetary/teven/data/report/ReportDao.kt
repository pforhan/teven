package alphainterplanetary.teven.data.report

import alphainterplanetary.teven.api.model.report.InventoryUsageReportResponse
import alphainterplanetary.teven.api.model.report.StaffHoursReportRequest
import alphainterplanetary.teven.api.model.report.StaffHoursReportResponse
import alphainterplanetary.teven.data.dbQuery
import alphainterplanetary.teven.data.inventory.InventoryItems
import alphainterplanetary.teven.data.inventory.InventoryUsage
import alphainterplanetary.teven.data.user.Users
import java.time.LocalDate
import org.jetbrains.exposed.v1.core.ResultRow
import org.jetbrains.exposed.v1.core.and
import org.jetbrains.exposed.v1.core.greaterEq
import org.jetbrains.exposed.v1.core.lessEq
import org.jetbrains.exposed.v1.core.sum
import org.jetbrains.exposed.v1.jdbc.select

class ReportDao {
  suspend fun getStaffHoursReport(
    staffHoursReportRequest: StaffHoursReportRequest,
  ): List<StaffHoursReportResponse> = dbQuery {
    val totalHours = StaffHours.hoursWorked.sum()
    (StaffHours innerJoin Users)
      .select(StaffHours.userId, Users.username, Users.displayName, totalHours)
      .where {
        (StaffHours.date greaterEq LocalDate.parse(staffHoursReportRequest.startDate)) and
          (StaffHours.date lessEq LocalDate.parse(staffHoursReportRequest.endDate))
      }
      .groupBy(StaffHours.userId, Users.username, Users.displayName)
      .map { row: ResultRow ->
        StaffHoursReportResponse(
          userId = row[StaffHours.userId].value,
          username = row[Users.username],
          displayName = row[Users.displayName],
          totalHoursWorked = row[totalHours] ?: 0,
        )
      }
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
