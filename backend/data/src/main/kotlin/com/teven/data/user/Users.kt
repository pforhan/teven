package com.teven.data.user

import org.jetbrains.exposed.dao.id.IntIdTable

object Users : IntIdTable() {
  val username = varchar("username", 255).uniqueIndex()
  val passwordHash = varchar("password", 255)
  val email = varchar("email", 255).uniqueIndex()
  val displayName = varchar("display_name", 255)
  val organizationId =
    integer("organization_id").references(com.teven.data.organization.Organizations.id)
}
