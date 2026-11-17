package alphainterplanetary.teven.data.user

import org.jetbrains.exposed.v1.core.dao.id.IntIdTable
import org.jetbrains.exposed.v1.javatime.timestampWithTimeZone

object Users : IntIdTable() {
  val username = varchar("username", 255).uniqueIndex()
  val passwordHash = varchar("password", 255)
  val email = varchar("email", 255).uniqueIndex()
  val displayName = varchar("display_name", 255)
  val deletedAt = timestampWithTimeZone("deleted_at").nullable()
}
