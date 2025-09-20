package alphainterplanetary.teven.data.role

import alphainterplanetary.teven.data.user.Users
import org.jetbrains.exposed.v1.core.Table

object UserRoles : Table() {
  val userId = integer("user_id").references(Users.id)
  val roleId = integer("role_id").references(Roles.id)
  override val primaryKey = PrimaryKey(userId, roleId)
}