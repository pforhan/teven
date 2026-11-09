package alphainterplanetary.teven.data.report

import alphainterplanetary.teven.api.model.report.InventoryUsageReportResponse
import alphainterplanetary.teven.api.model.report.StaffHoursReportRequest
import alphainterplanetary.teven.api.model.report.StaffHoursReportResponse
import alphainterplanetary.teven.data.dbQuery
import alphainterplanetary.teven.data.inventory.InventoryItems
import alphainterplanetary.teven.data.inventory.InventoryUsage
import alphainterplanetary.teven.data.user.UserOrganizations
import alphainterplanetary.teven.data.user.Users
import java.time.LocalDate
import org.jetbrains.exposed.v1.core.ResultRow
import org.jetbrains.exposed.v1.core.and
import org.jetbrains.exposed.v1.core.eq
import org.jetbrains.exposed.v1.core.greaterEq
import org.jetbrains.exposed.v1.core.lessEq
import org.jetbrains.exposed.v1.core.sum
import org.jetbrains.exposed.v1.jdbc.select

class ReportDao {
  suspend fun getStaffHoursReport(
    staffHoursReportRequest: StaffHoursReportRequest,
    organizationId: Int,
  ): List<StaffHoursReportResponse> = dbQuery {
    val totalHours = StaffHours.hoursWorked.sum()
    val start = LocalDate.parse(staffHoursReportRequest.startDate)
    val end = LocalDate.parse(staffHoursReportRequest.endDate)
    (StaffHours innerJoin Users innerJoin UserOrganizations)
      .select(StaffHours.userId, Users.username, Users.displayName, totalHours)
      .where {
        (StaffHours.date greaterEq start) and
          (StaffHours.date lessEq end) and
          (UserOrganizations.organizationId eq organizationId)
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

  suspend fun getInventoryUsageReport(organizationId: Int): List<InventoryUsageReportResponse> = dbQuery {
    val usageSum = InventoryUsage.quantityUsed.sum()
    (InventoryUsage innerJoin InventoryItems)
      .select(InventoryItems.id, InventoryItems.name, usageSum)
      .where { InventoryItems.organizationId eq organizationId }
      .groupBy(InventoryItems.id, InventoryItems.name)
      .map { row: ResultRow ->
        InventoryUsageReportResponse(
          inventoryId = row[InventoryItems.id].value,
          name = row[InventoryItems.name],
          usageCount = row[usageSum] ?: 0,
        )
      }
  }
}
