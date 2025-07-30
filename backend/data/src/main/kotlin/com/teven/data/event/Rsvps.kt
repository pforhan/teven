package com.teven.data.event

import org.jetbrains.exposed.dao.id.IntIdTable

object Rsvps : IntIdTable() {
  val eventId = integer("event_id").references(Events.id)
  val userId = reference("user_id", com.teven.data.user.Users.id)
  val availability = varchar("availability", 50)
}
