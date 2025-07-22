
package com.teven.data

import com.teven.data.user.Users
import com.teven.data.user.StaffDetails
import com.teven.data.event.Events
import com.teven.data.event.EventStaff
import com.teven.data.event.Rsvps
import com.teven.data.event.EventInventory
import com.teven.data.customer.Customers
import com.teven.data.inventory.InventoryItems
import com.teven.data.inventory.InventoryUsage
import com.teven.data.role.UserRoles
import com.teven.data.report.StaffHours
import com.teven.data.role.Roles
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.SchemaUtils
import org.jetbrains.exposed.sql.transactions.transaction

object DatabaseFactory {
    fun init() {
        val driverClassName = "org.postgresql.Driver"
        val jdbcUrl = "jdbc:postgresql://localhost:5432/teven_db"
        val user = "teven_user"
        val password = "teven_password"

        Database.connect(jdbcUrl, driverClassName, user, password)

        transaction {
            SchemaUtils.create(Users, StaffDetails, Events, EventStaff, Rsvps, Customers, InventoryItems, StaffHours, Roles, EventInventory, InventoryUsage, UserRoles)
        }
    }
}
