package com.teven.data.user

import com.teven.api.model.user.CreateUserRequest
import com.teven.api.model.user.UpdateUserRequest
import com.teven.api.model.user.UserResponse
import com.teven.core.security.PasswordHasher
import com.teven.data.dbQuery
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.select
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.update

class UserDao {
  private fun toUserResponse(row: ResultRow): UserResponse {
    return UserResponse(
      userId = row[Users.id].value,
      username = row[Users.username],
      email = row[Users.email],
      displayName = row[Users.displayName],
      passwordHash = row[Users.passwordHash],
      // TODO add data from UserRoles
      role = "",
      // TODO: Add staff details
      staffDetails = null,
    )
  }

  suspend fun createUser(registerRequest: CreateUserRequest): UserResponse = dbQuery {
    val id = Users.insert {
      it[username] = registerRequest.username
      it[email] = registerRequest.email
      it[displayName] = registerRequest.displayName
      it[passwordHash] = PasswordHasher.hashPassword(registerRequest.password)
      // TODO link role if caller has permission
    } get Users.id

    UserResponse(
      userId = id.value,
      username = registerRequest.username,
      email = registerRequest.email,
      displayName = registerRequest.displayName,
      // TODO this isn't the right value:
      role = "superadmin",
      passwordHash = PasswordHasher.hashPassword(registerRequest.password)
    )
  }

  suspend fun getAllUsers(): List<UserResponse> = dbQuery {
    Users.selectAll().map { toUserResponse(it) }
  }

  suspend fun getUserById(userId: Int): UserResponse? = dbQuery {
    Users.select { Users.id eq userId }
      .mapNotNull { toUserResponse(it) }
      .singleOrNull()
  }

  suspend fun getUserByUsername(username: String): UserResponse? = dbQuery {
    Users.select { Users.username eq username }
      .mapNotNull { toUserResponse(it) }
      .singleOrNull()
  }

  suspend fun updateUser(userId: Int, updateUserRequest: UpdateUserRequest): UserResponse? =
    dbQuery {
      val updatedRows = Users.update({ Users.id eq userId }) {
        updateUserRequest.email?.let { email -> it[Users.email] = email }
        updateUserRequest.displayName?.let { displayName -> it[Users.displayName] = displayName }
      }
      if (updatedRows > 0) {
        getUserById(userId)
      } else {
        null
      }
    }

  suspend fun areInSameOrganization(userId1: Int, userId2: Int): Boolean = dbQuery {
    val org1 = UserOrganizations.select { UserOrganizations.userId eq userId1 }
      .map { it[UserOrganizations.organizationId] }.singleOrNull()
    val org2 = UserOrganizations.select { UserOrganizations.userId eq userId2 }
      .map { it[UserOrganizations.organizationId] }.singleOrNull()
    org1 != null && org1 == org2
  }
}
