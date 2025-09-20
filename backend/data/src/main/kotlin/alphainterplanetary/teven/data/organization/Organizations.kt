package alphainterplanetary.teven.data.organization

import org.jetbrains.exposed.v1.core.dao.id.IntIdTable

object Organizations : IntIdTable() {
  val name = varchar("name", 255).uniqueIndex()
  val contactInformation = varchar("contact_information", 255)
}
