package com.teven.data

import com.teven.data.customer.Customers
import com.teven.data.event.EventInventory
import com.teven.data.event.EventStaff
import com.teven.data.event.Events
import com.teven.data.event.Rsvps
import com.teven.data.inventory.InventoryItems
import com.teven.data.inventory.InventoryUsage
import com.teven.data.organization.Organizations
import com.teven.data.report.StaffHours
import com.teven.data.role.Roles
import com.teven.data.role.UserRoles
import com.teven.data.user.StaffDetails
import com.teven.data.user.Users
import kotlinx.coroutines.Dispatchers
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.SchemaUtils
import org.jetbrains.exposed.sql.Transaction
import org.jetbrains.exposed.sql.transactions.experimental.newSuspendedTransaction
import org.jetbrains.exposed.sql.transactions.transaction

object DatabaseFactory {
  fun init() {
    val driverClassName = "org.postgresql.Driver"
    val jdbcUrl = System.getenv("DB_URL") ?: "jdbc:postgresql://localhost:5432/teven_db"
    val user = System.getenv("DB_USER") ?: "teven_user"
    val password = System.getenv("DB_PASSWORD") ?: "teven_password"

    Database.connect(jdbcUrl, driverClassName, user, password)

    transaction {
      SchemaUtils.create(
        Users,
        StaffDetails,
        Events,
        EventStaff,
        Rsvps,
        Customers,
        InventoryItems,
        StaffHours,
        Roles,
        EventInventory,
        InventoryUsage,
        UserRoles,
        Organizations
      )
    }
  }
}

suspend fun <T> dbQuery(block: suspend Transaction.() -> T): T =
  newSuspendedTransaction(Dispatchers.IO) { block() }
