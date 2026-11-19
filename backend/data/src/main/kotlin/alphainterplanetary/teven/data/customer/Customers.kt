package alphainterplanetary.teven.data.customer

import alphainterplanetary.teven.data.organization.Organizations
import org.jetbrains.exposed.v1.core.Table
import org.jetbrains.exposed.v1.javatime.timestampWithTimeZone

object Customers : Table() {
  val id = integer("id").autoIncrement()
  val name = varchar("name", 255)
  val phone = varchar("phone", 20)
  val address = varchar("address", 255)
  val latitude = double("latitude").nullable()
  val longitude = double("longitude").nullable()
  val formattedAddress = varchar("formatted_address", 255).nullable()
  val notes = text("notes")
  val organizationId = integer("organization_id").references(Organizations.id)
  val deletedAt = timestampWithTimeZone("deleted_at").nullable()

  override val primaryKey = PrimaryKey(id)
}