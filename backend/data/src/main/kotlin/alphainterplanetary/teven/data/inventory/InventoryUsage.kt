package alphainterplanetary.teven.data.inventory

import org.jetbrains.exposed.v1.core.ReferenceOption
import org.jetbrains.exposed.v1.core.dao.id.IntIdTable

object InventoryUsage : IntIdTable() {
  val inventoryId = reference("inventory_id", InventoryItems.id, onDelete = ReferenceOption.CASCADE)
  val eventId =
    reference("event_id", alphainterplanetary.teven.data.event.Events.id, onDelete = ReferenceOption.CASCADE)
  val quantityUsed = integer("quantity_used")
  val usageDate = varchar("usage_date", 255)
}
