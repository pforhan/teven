package alphainterplanetary.teven.data.event

import org.jetbrains.exposed.v1.core.dao.id.IntIdTable

object EventStaff : IntIdTable() {
  val eventId = integer("event_id").references(Events.id)
  val userId = reference("user_id", alphainterplanetary.teven.data.user.Users.id)
}