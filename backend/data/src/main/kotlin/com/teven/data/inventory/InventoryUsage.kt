package com.teven.data.inventory

import org.jetbrains.exposed.dao.id.IntIdTable
import org.jetbrains.exposed.sql.ReferenceOption

object InventoryUsage : IntIdTable() {
  val inventoryId = reference("inventory_id", InventoryItems.id, onDelete = ReferenceOption.CASCADE)
  val eventId =
    reference("event_id", com.teven.data.event.Events.id, onDelete = ReferenceOption.CASCADE)
  val quantityUsed = integer("quantity_used")
  val usageDate = varchar("usage_date", 255)
}
