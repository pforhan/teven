package alphainterplanetary.teven.data.role

import org.jetbrains.exposed.dao.id.IntIdTable
import org.jetbrains.exposed.sql.Column

object Roles : IntIdTable() {
  val roleName = varchar("role_name", 255).uniqueIndex()
  val permissions: Column<String> = text("permissions")
}
