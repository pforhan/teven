package com.teven.data.inventory

import org.jetbrains.exposed.dao.id.IntIdTable

object InventoryItems : IntIdTable() {
  val name = varchar("name", 255)
  val description = text("description")
  val quantity = integer("quantity")
}
