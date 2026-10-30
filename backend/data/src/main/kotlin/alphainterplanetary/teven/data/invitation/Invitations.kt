package alphainterplanetary.teven.data.invitation

import alphainterplanetary.teven.data.organization.Organizations
import alphainterplanetary.teven.data.role.Roles
import alphainterplanetary.teven.data.user.Users
import org.jetbrains.exposed.v1.core.dao.id.IntIdTable
import org.jetbrains.exposed.v1.javatime.CurrentTimestampWithTimeZone
import org.jetbrains.exposed.v1.javatime.timestampWithTimeZone

object Invitations : IntIdTable() {
  val organizationId = reference("organization_id", Organizations.id)
  val roleId = reference("role_id", alphainterplanetary.teven.data.role.Roles.id)
  val token = varchar("token", 255).uniqueIndex()
  val expiresAt = timestampWithTimeZone("expires_at")
  val usedByUserId = reference("used_by_user_id", Users.id).nullable()
  val createdAt = timestampWithTimeZone("created_at").defaultExpression(CurrentTimestampWithTimeZone)
  val note = varchar("note", 255).nullable()
}