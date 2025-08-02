package com.teven.data.user

import com.teven.data.organization.Organizations
import org.jetbrains.exposed.sql.Table

object UserOrganizations : Table() {
  val userId = integer("user_id").references(Users.id)
  val organizationId = integer("organization_id").references(Organizations.id)
  override val primaryKey = PrimaryKey(userId, organizationId)
}
