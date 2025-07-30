package com.teven.data.role

import org.jetbrains.exposed.dao.id.IntIdTable
import org.jetbrains.exposed.sql.ReferenceOption

object UserRoles : IntIdTable() {
  val userId =
    reference("user_id", com.teven.data.user.Users.id, onDelete = ReferenceOption.CASCADE)
  val roleId = reference("role_id", Roles.id, onDelete = ReferenceOption.CASCADE)
}
