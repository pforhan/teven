package alphainterplanetary.teven.data.report

import org.jetbrains.exposed.dao.id.IntIdTable

object StaffHours : IntIdTable() {
  val userId = reference("user_id", alphainterplanetary.teven.data.user.Users.id)
  val date = varchar("date", 255)
  val hoursWorked = integer("hours_worked")
}
