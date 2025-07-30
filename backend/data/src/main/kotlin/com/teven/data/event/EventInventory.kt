package com.teven.data.event

import org.jetbrains.exposed.dao.id.IntIdTable
import org.jetbrains.exposed.sql.ReferenceOption

object EventInventory : IntIdTable() {
  val eventId = reference("event_id", Events.id, onDelete = ReferenceOption.CASCADE)
  val inventoryId = reference("inventory_id", com.teven.data.inventory.InventoryItems.id)
}
