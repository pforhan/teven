package com.teven.data.report

import com.teven.api.model.report.InventoryUsageReportResponse
import com.teven.api.model.report.StaffHoursReportRequest
import com.teven.api.model.report.StaffHoursReportResponse
import com.teven.data.inventory.InventoryItems
import com.teven.data.inventory.InventoryUsage
import com.teven.data.user.Users
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.and
import org.jetbrains.exposed.sql.select
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.sum
import org.jetbrains.exposed.sql.transactions.transaction

class ReportDao {
    private fun toStaffHoursReportResponse(row: ResultRow): StaffHoursReportResponse {
        return StaffHoursReportResponse(
            userId = row[StaffHours.userId].value,
            username = row[Users.username],
            totalHoursWorked = row[StaffHours.hoursWorked]
        )
    }

    fun getStaffHoursReport(staffHoursReportRequest: StaffHoursReportRequest): List<StaffHoursReportResponse> {
        return transaction {
            (StaffHours innerJoin Users)
                .select {
                    (StaffHours.date greaterEq staffHoursReportRequest.startDate) and
                    (StaffHours.date lessEq staffHoursReportRequest.endDate)
                }.map { row: ResultRow -> toStaffHoursReportResponse(row) }
        }
    }

    fun getInventoryUsageReport(): List<InventoryUsageReportResponse> {
        return transaction {
            (InventoryUsage innerJoin InventoryItems)
                .slice(InventoryItems.id, InventoryItems.name, InventoryUsage.quantityUsed.sum())
                .selectAll()
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
}
