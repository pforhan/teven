package alphainterplanetary.teven.data.report

import org.jetbrains.exposed.v1.core.dao.id.IntIdTable
import org.jetbrains.exposed.v1.javatime.date

object StaffHours : IntIdTable() {
  val userId = reference("user_id", alphainterplanetary.teven.data.user.Users.id)
  val date = date("date")
  val hoursWorked = integer("hours_worked")
}
