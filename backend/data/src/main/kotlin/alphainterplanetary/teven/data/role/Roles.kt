package alphainterplanetary.teven.data.role

import org.jetbrains.exposed.v1.core.Column
import org.jetbrains.exposed.v1.core.dao.id.IntIdTable

object Roles : IntIdTable() {
  val roleName = varchar("role_name", 255).uniqueIndex()
  val permissions: Column<String> = text("permissions")
}
