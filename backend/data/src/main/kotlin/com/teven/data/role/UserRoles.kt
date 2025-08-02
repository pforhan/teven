package com.teven.data.role

import com.teven.data.user.Users
import org.jetbrains.exposed.sql.Table

object UserRoles : Table() {
  val userId = integer("user_id").references(Users.id)
  val roleId = integer("role_id").references(Roles.id)
  override val primaryKey = PrimaryKey(userId, roleId)
}