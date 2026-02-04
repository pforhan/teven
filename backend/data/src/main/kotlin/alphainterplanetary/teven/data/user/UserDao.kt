package alphainterplanetary.teven.data.user

import alphainterplanetary.teven.api.model.common.PaginatedResponse
import alphainterplanetary.teven.api.model.organization.OrganizationResponse
import alphainterplanetary.teven.api.model.user.CreateUserRequest
import alphainterplanetary.teven.api.model.user.UpdateUserRequest
import alphainterplanetary.teven.core.security.PasswordHasher
import alphainterplanetary.teven.core.user.User
import alphainterplanetary.teven.data.dbQuery
import alphainterplanetary.teven.data.organization.Organizations
import org.jetbrains.exposed.v1.core.Op
import org.jetbrains.exposed.v1.core.ResultRow
import org.jetbrains.exposed.v1.core.SortOrder
import org.jetbrains.exposed.v1.core.and
import org.jetbrains.exposed.v1.core.eq
import org.jetbrains.exposed.v1.core.inList
import org.jetbrains.exposed.v1.core.like
import org.jetbrains.exposed.v1.core.lowerCase
import org.jetbrains.exposed.v1.core.or
import org.jetbrains.exposed.v1.jdbc.insert
import org.jetbrains.exposed.v1.jdbc.selectAll
import org.jetbrains.exposed.v1.jdbc.update

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
      it[UserOrganizations.organizationId] = registerRequest.organizationId
    }

    User(
      userId = id.value,
      username = registerRequest.username,
      email = registerRequest.email,
      displayName = registerRequest.displayName,
      passwordHash = PasswordHasher.hashPassword(registerRequest.password)
    )
  }

  suspend fun getUsers(
    organizationId: Int?,
    search: String?,
    limit: Int?,
    offset: Long?,
    sortBy: String?,
    sortOrder: String?,
  ): PaginatedResponse<User> = dbQuery {
    val conditions = mutableListOf<Op<Boolean>>()
    if (organizationId != null) {
      val userIdsInOrg = UserOrganizations.selectAll()
        .where { UserOrganizations.organizationId eq organizationId }
        .map { it[UserOrganizations.userId] }
      conditions.add(Users.id inList userIdsInOrg)
    }
    search?.let { val s = "%${it.lowercase()}%"
      conditions.add((Users.username.lowerCase() like s) or (Users.email.lowerCase() like s) or (Users.displayName.lowerCase() like s))
    }

    val query = if (conditions.isEmpty()) {
      Users.selectAll()
    } else {
      val combinedCondition = conditions.reduce { acc, op -> acc and op }
      Users.selectAll().where { combinedCondition }
    }

    val total = query.count()

    val sort = if (sortOrder == "desc") SortOrder.DESC else SortOrder.ASC
    when (sortBy) {
      "username" -> query.orderBy(Users.username, sort)
      "email" -> query.orderBy(Users.email, sort)
      "displayName" -> query.orderBy(Users.displayName, sort)
      else -> query.orderBy(Users.id, sort)
    }

    offset?.let { query.offset(it) }
    limit?.let { query.limit(it) }

    val users = query.map { toUser(it) }

    PaginatedResponse(
      items = users,
      total = total,
      offset = offset ?: 0,
      limit = limit ?: 0,
    )
  }

  suspend fun getAllUsers(): List<User> = dbQuery {
    Users.selectAll().map { toUser(it) }
  }

  suspend fun getUserById(userId: Int): User = dbQuery {
    Users.selectAll()
      .where { Users.id eq userId }
      .mapNotNull { toUser(it) }
      .single()
  }

  suspend fun getUserByUsername(username: String): User? = dbQuery {
    Users.selectAll()
      .where { Users.username eq username }
      .mapNotNull { toUser(it) }
      .singleOrNull()
  }

  suspend fun getUserByEmail(email: String): User? = dbQuery {
    Users.selectAll()
      .where { Users.email eq email }
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
    val org1 = UserOrganizations.selectAll()
      .where { UserOrganizations.userId eq userId1 }
      .map { it[UserOrganizations.organizationId] }.singleOrNull()
    val org2 = UserOrganizations.selectAll()
      .where { UserOrganizations.userId eq userId2 }
      .map { it[UserOrganizations.organizationId] }.singleOrNull()
    org1 != null && org1 == org2
  }

  suspend fun getOrganizationForUser(userId: Int): OrganizationResponse = dbQuery {
    val organizationId = UserOrganizations.selectAll()
      .where { UserOrganizations.userId eq userId }
      .map { it[UserOrganizations.organizationId] }.single()

    Organizations.selectAll()
      .where { Organizations.id eq organizationId }
      .single().let {
        OrganizationResponse(
          organizationId = it[Organizations.id].value,
          name = it[Organizations.name],
          contactInformation = it[Organizations.contactInformation]
        )
      }
  }

  suspend fun getUsersByOrganization(organizationId: Int): List<User> = dbQuery {
    val userIds = UserOrganizations.selectAll()
      .where { UserOrganizations.organizationId eq organizationId }
      .map { it[UserOrganizations.userId] }
    Users.selectAll()
      .where { Users.id inList userIds }
      .map { toUser(it) }
  }
}
