package alphainterplanetary.teven.data.user

import org.jetbrains.exposed.v1.core.dao.id.IntIdTable

object Users : IntIdTable() {
  val username = varchar("username", 255).uniqueIndex()
  val passwordHash = varchar("password", 255)
  val email = varchar("email", 255).uniqueIndex()
  val displayName = varchar("display_name", 255)
}
