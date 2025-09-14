package alphainterplanetary.teven.data.customer

import alphainterplanetary.teven.data.organization.Organizations
import org.jetbrains.exposed.sql.Table

object Customers : Table() {
  val id = integer("id").autoIncrement()
  val name = varchar("name", 255)
  val phone = varchar("phone", 20)
  val address = varchar("address", 255)
  val notes = text("notes")
  val organizationId = integer("organization_id").references(Organizations.id)

  override val primaryKey = PrimaryKey(id)
}