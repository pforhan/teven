
package com.teven.data.user

import com.teven.api.model.auth.RegisterRequest
import com.teven.api.model.auth.UserResponse
import com.teven.api.model.auth.StaffDetails as ApiStaffDetails
import com.teven.core.security.PasswordHasher
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.transactions.transaction
import org.jetbrains.exposed.sql.select
import org.jetbrains.exposed.sql.update
import org.jetbrains.exposed.sql.and

class UserDao {
    fun createUser(registerRequest: RegisterRequest): UserResponse {
        return transaction {
            val id = Users.insert {
                it[username] = registerRequest.username
                it[email] = registerRequest.email
                it[displayName] = registerRequest.displayName
                it[passwordHash] = PasswordHasher.hashPassword(registerRequest.password)
                it[role] = registerRequest.role
            } get Users.id

            UserResponse(
                userId = id.value,
                username = registerRequest.username,
                email = registerRequest.email,
                displayName = registerRequest.displayName,
                role = registerRequest.role,
                passwordHash = PasswordHasher.hashPassword(registerRequest.password)
            )
        }
    }

    fun findByUsername(username: String): UserResponse? {
        return transaction {
            Users.select { Users.username eq username }
                .mapNotNull { row ->
                    val staffDetailsRow = StaffDetails.select { StaffDetails.userId eq row[Users.id].value }.singleOrNull()
                    val staffDetails = if (staffDetailsRow != null) {
                        ApiStaffDetails(
                            contactInformation = staffDetailsRow[StaffDetails.contactInformation],
                            skills = staffDetailsRow[StaffDetails.skills].split(","),
                            hoursWorked = staffDetailsRow[StaffDetails.hoursWorked],
                            phoneNumber = staffDetailsRow[StaffDetails.phoneNumber],
                            dateOfBirth = staffDetailsRow[StaffDetails.dateOfBirth]
                        )
                    } else {
                        null
                    }
                    UserResponse(
                        userId = row[Users.id].value,
                        username = row[Users.username],
                        email = row[Users.email],
                        displayName = row[Users.displayName],
                        role = row[Users.role],
                        passwordHash = row[Users.passwordHash],
                        staffDetails = staffDetails
                    )
                }
                .singleOrNull()
        }
    }

    fun findByEmail(email: String): UserResponse? {
        return transaction {
            Users.select { Users.email eq email }
                .mapNotNull { row ->
                    val staffDetailsRow = StaffDetails.select { StaffDetails.userId eq row[Users.id].value }.singleOrNull()
                    val staffDetails = if (staffDetailsRow != null) {
                        ApiStaffDetails(
                            contactInformation = staffDetailsRow[StaffDetails.contactInformation],
                            skills = staffDetailsRow[StaffDetails.skills].split(","),
                            hoursWorked = staffDetailsRow[StaffDetails.hoursWorked],
                            phoneNumber = staffDetailsRow[StaffDetails.phoneNumber],
                            dateOfBirth = staffDetailsRow[StaffDetails.dateOfBirth]
                        )
                    } else {
                        null
                    }
                    UserResponse(
                        userId = row[Users.id].value,
                        username = row[Users.username],
                        email = row[Users.email],
                        displayName = row[Users.displayName],
                        role = row[Users.role],
                        passwordHash = row[Users.passwordHash],
                        staffDetails = staffDetails
                    )
                }
                .singleOrNull()
        }
    }

    fun findById(userId: Int): UserResponse? {
        return transaction {
            Users.select { Users.id eq userId }
                .mapNotNull { row ->
                    val staffDetailsRow = StaffDetails.select { StaffDetails.userId eq row[Users.id].value }.singleOrNull()
                    val staffDetails = if (staffDetailsRow != null) {
                        ApiStaffDetails(
                            contactInformation = staffDetailsRow[StaffDetails.contactInformation],
                            skills = staffDetailsRow[StaffDetails.skills].split(","),
                            hoursWorked = staffDetailsRow[StaffDetails.hoursWorked],
                            phoneNumber = staffDetailsRow[StaffDetails.phoneNumber],
                            dateOfBirth = staffDetailsRow[StaffDetails.dateOfBirth]
                        )
                    } else {
                        null
                    }
                    UserResponse(
                        userId = row[Users.id].value,
                        username = row[Users.username],
                        email = row[Users.email],
                        displayName = row[Users.displayName],
                        role = row[Users.role],
                        passwordHash = row[Users.passwordHash],
                        staffDetails = staffDetails
                    )
                }
                .singleOrNull()
        }
    }

    fun updateUser(userId: Int, updateUserRequest: com.teven.api.model.auth.UpdateUserRequest): Boolean {
        return transaction {
            val userUpdated = Users.update({ Users.id eq userId }) {
                updateUserRequest.email?.let { email -> it[Users.email] = email }
                updateUserRequest.displayName?.let { displayName -> it[Users.displayName] = displayName }
            } > 0

            updateUserRequest.staffDetails?.let { staffDetailsRequest ->
                val staffDetailsUpdated = StaffDetails.update({ StaffDetails.userId eq userId }) {
                    staffDetailsRequest.contactInformation?.let { contact -> it[StaffDetails.contactInformation] = contact }
                    staffDetailsRequest.skills?.let { skills -> it[StaffDetails.skills] = skills.joinToString(",") }
                    staffDetailsRequest.phoneNumber?.let { phone -> it[StaffDetails.phoneNumber] = phone }
                    staffDetailsRequest.dateOfBirth?.let { dob -> it[StaffDetails.dateOfBirth] = dob }
                } > 0

                if (!staffDetailsUpdated) {
                    StaffDetails.insert {
                        it[StaffDetails.userId] = userId
                        staffDetailsRequest.contactInformation?.let { contact -> it[StaffDetails.contactInformation] = contact }
                        staffDetailsRequest.skills?.let { skills -> it[StaffDetails.skills] = skills.joinToString(",") }
                        staffDetailsRequest.phoneNumber?.let { phone -> it[StaffDetails.phoneNumber] = phone }
                        staffDetailsRequest.dateOfBirth?.let { dob -> it[StaffDetails.dateOfBirth] = dob }
                        it[StaffDetails.hoursWorked] = 0 // Initialize hoursWorked for new staff
                    }
                }
            }
            userUpdated || (updateUserRequest.staffDetails != null)
        }
    }
}
