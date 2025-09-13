package com.teven.data.user

import com.teven.api.model.organization.OrganizationResponse
import com.teven.api.model.user.CreateUserRequest
import com.teven.api.model.user.UpdateUserRequest
import com.teven.core.security.PasswordHasher
import com.teven.core.user.User
import com.teven.data.dbQuery
import com.teven.data.organization.Organizations
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.select
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.update

class UserDao {
  private fun toUser(row: ResultRow): User {
    return User(
      userId = row[Users.id].value,
      username = row[Users.username],
      email = row[Users.email],
      displayName = row[Users.displayName],
      passwordHash = row[Users.passwordHash],
    )
  }

  suspend fun createUser(registerRequest: CreateUserRequest): User = dbQuery {
    val id = Users.insert {
      it[username] = registerRequest.username
      it[email] = registerRequest.email
      it[displayName] = registerRequest.displayName
      it[passwordHash] = PasswordHasher.hashPassword(registerRequest.password)
    } get Users.id

    UserOrganizations.insert {
      it[userId] = id.value
      it[organizationId] = registerRequest.organizationId
    }

    User(
      userId = id.value,
      username = registerRequest.username,
      email = registerRequest.email,
      displayName = registerRequest.displayName,
      passwordHash = PasswordHasher.hashPassword(registerRequest.password)
    )
  }

  suspend fun getAllUsers(): List<User> = dbQuery {
    Users.selectAll().map { toUser(it) }
  }

  suspend fun getUserById(userId: Int): User = dbQuery {
    Users.select { Users.id eq userId }
      .mapNotNull { toUser(it) }
      .single()
  }

  suspend fun getUserByUsername(username: String): User? = dbQuery {
    Users.select { Users.username eq username }
      .mapNotNull { toUser(it) }
      .singleOrNull()
  }

  suspend fun updateUser(userId: Int, updateUserRequest: UpdateUserRequest): User? =
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

  suspend fun getOrganizationForUser(userId: Int): OrganizationResponse = dbQuery {
    val organizationId = UserOrganizations.select { UserOrganizations.userId eq userId }
      .map { it[UserOrganizations.organizationId] }.single()

    Organizations.select { Organizations.id eq organizationId }.single().let {
      OrganizationResponse(
        organizationId = it[Organizations.id].value,
        name = it[Organizations.name],
        contactInformation = it[Organizations.contactInformation]
      )
    }
  }

  suspend fun getUsersByOrganization(organizationId: Int): List<User> = dbQuery {
    val userIds = UserOrganizations.select { UserOrganizations.organizationId eq organizationId }
      .map { it[UserOrganizations.userId] }
    Users.select { Users.id inList userIds }.map { toUser(it) }
  }
}
