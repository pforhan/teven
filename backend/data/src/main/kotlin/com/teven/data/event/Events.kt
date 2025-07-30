package com.teven.data.event

import org.jetbrains.exposed.dao.id.IntIdTable

object Events : IntIdTable() {
  val title = varchar("title", 255)
  val date = varchar("date", 255)
  val time = varchar("time", 255)
  val location = varchar("location", 255)
  val description = text("description")
  val customerId = integer("customer_id")
  val openInvitation = bool("open_invitation").default(false)
  val numberOfStaffNeeded = integer("number_of_staff_needed").default(0)
}
