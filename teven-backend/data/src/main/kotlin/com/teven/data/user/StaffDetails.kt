
package com.teven.data.user

import org.jetbrains.exposed.dao.id.IntIdTable
import org.jetbrains.exposed.sql.ReferenceOption

object StaffDetails : IntIdTable() {
    val userId = reference("user_id", Users.id, onDelete = ReferenceOption.CASCADE).uniqueIndex()
    val contactInformation = varchar("contact_information", 255)
    val skills = text("skills") // Storing as comma-separated string for simplicity
    val hoursWorked = integer("hours_worked")
    val phoneNumber = varchar("phone_number", 20)
    val dateOfBirth = varchar("date_of_birth", 20)
}
