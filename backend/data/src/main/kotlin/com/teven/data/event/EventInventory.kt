package com.teven.data.event

import com.teven.data.inventory.InventoryItems
import org.jetbrains.exposed.sql.Table

object EventInventory : Table() {
  val eventId = integer("event_id").references(Events.id)
  val inventoryItemId = integer("inventory_item_id").references(InventoryItems.id)
  val quantity = integer("quantity")

  override val primaryKey = PrimaryKey(eventId, inventoryItemId)
}