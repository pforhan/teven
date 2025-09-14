package alphainterplanetary.teven.data.inventory

import alphainterplanetary.teven.data.organization.Organizations
import org.jetbrains.exposed.dao.id.IntIdTable

object InventoryItems : IntIdTable() {
  val name = varchar("name", 255)
  val description = text("description")
  val quantity = integer("quantity")
  val organizationId = integer("organization_id").references(Organizations.id)
}
