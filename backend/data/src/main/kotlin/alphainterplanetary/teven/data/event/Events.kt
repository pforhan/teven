package alphainterplanetary.teven.data.event

import alphainterplanetary.teven.data.customer.Customers
import alphainterplanetary.teven.data.organization.Organizations
import org.jetbrains.exposed.v1.core.Table

object Events : Table() {
  val id = integer("id").autoIncrement()
  val title = varchar("title", 255)
  val date = varchar("date", 255)
  val time = varchar("time", 255)
  val location = varchar("location", 255)
  val description = text("description")
  val customerId = integer("customer_id").references(Customers.id)
  val organizationId = integer("organization_id").references(Organizations.id)
  val openInvitation = bool("open_invitation")
  val numberOfStaffNeeded = integer("number_of_staff_needed")

  override val primaryKey = PrimaryKey(id)
}