package alphainterplanetary.teven.data.invitation

import alphainterplanetary.teven.data.organization.Organizations
import alphainterplanetary.teven.data.role.Roles
import alphainterplanetary.teven.data.user.Users
import org.jetbrains.exposed.v1.core.dao.id.IntIdTable
import org.jetbrains.exposed.v1.javatime.CurrentDateTime
import org.jetbrains.exposed.v1.javatime.datetime

object Invitations : IntIdTable() {
  val organizationId = reference("organization_id", Organizations.id)
  val roleId = reference("role_id", alphainterplanetary.teven.data.role.Roles.id)
  val token = varchar("token", 255).uniqueIndex()
  val expiresAt = datetime("expires_at")
  val usedByUserId = reference("used_by_user_id", Users.id).nullable()
  val createdAt = datetime("created_at").defaultExpression(CurrentDateTime)
}