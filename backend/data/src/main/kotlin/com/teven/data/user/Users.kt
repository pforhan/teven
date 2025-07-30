package com.teven.data.user

import org.jetbrains.exposed.dao.id.IntIdTable

object Users : IntIdTable() {
  val username = varchar("username", 255).uniqueIndex()
  val email = varchar("email", 255).uniqueIndex()
  val displayName = varchar("display_name", 255)
  val passwordHash = varchar("password_hash", 255)
  val role = varchar("role", 50)
}
