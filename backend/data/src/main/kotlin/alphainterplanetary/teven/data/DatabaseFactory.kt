package alphainterplanetary.teven.data

import alphainterplanetary.teven.data.customer.Customers
import alphainterplanetary.teven.data.event.EventInventory
import alphainterplanetary.teven.data.event.EventStaff
import alphainterplanetary.teven.data.event.Events
import alphainterplanetary.teven.data.event.Rsvps
import alphainterplanetary.teven.data.inventory.InventoryItems
import alphainterplanetary.teven.data.inventory.InventoryUsage
import alphainterplanetary.teven.data.organization.Organizations
import alphainterplanetary.teven.data.report.StaffHours
import alphainterplanetary.teven.data.role.Roles
import alphainterplanetary.teven.data.role.UserRoles
import alphainterplanetary.teven.data.user.UserOrganizations
import alphainterplanetary.teven.data.user.Users
import kotlinx.coroutines.Dispatchers
import org.jetbrains.exposed.v1.core.Transaction
import org.jetbrains.exposed.v1.jdbc.Database
import org.jetbrains.exposed.v1.jdbc.SchemaUtils
import org.jetbrains.exposed.v1.jdbc.transactions.experimental.newSuspendedTransaction
import org.jetbrains.exposed.v1.jdbc.transactions.transaction

object DatabaseFactory {
  fun init() {
    val driverClassName = "org.postgresql.Driver"
    val jdbcUrl = System.getenv("DB_URL") ?: "jdbc:postgresql://localhost:5432/teven_db"
    val user = System.getenv("DB_USER") ?: "teven_user"
    val password = System.getenv("DB_PASSWORD") ?: "teven_password"

    val db = Database.connect(jdbcUrl, driverClassName, user, password)

    transaction {
      SchemaUtils.create(
        Customers,
        Events,
        EventInventory,
        EventStaff,
        Rsvps,
        InventoryItems,
        InventoryUsage,
        Organizations,
        StaffHours,
        Roles,
        UserRoles,
        Users,
        UserOrganizations,
      )
      SchemaUtils.createMissingTablesAndColumns(Events)
    }
  }
}

// TODO hook up r2dbc to remove this deprecated call
@Suppress("DEPRECATION")
suspend fun <T> dbQuery(block: suspend Transaction.() -> T): T =
  newSuspendedTransaction(Dispatchers.IO) { block() }