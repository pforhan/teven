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
import org.jetbrains.exposed.v1.core.isNull
import org.jetbrains.exposed.v1.core.isNotNull
import org.jetbrains.exposed.v1.core.like
import org.jetbrains.exposed.v1.core.lowerCase
import org.jetbrains.exposed.v1.core.or
import org.jetbrains.exposed.v1.jdbc.insert
import org.jetbrains.exposed.v1.jdbc.selectAll
import org.jetbrains.exposed.v1.jdbc.update
import java.time.OffsetDateTime

enum class UserStatusFilter {
  ACTIVE,
  DEACTIVATED,
  ALL,
}

class UserDao {
  private fun activeCondition(): Op<Boolean> = Users.deletedAt.isNull()

  private fun toUser(row: ResultRow): User {
    return User(
      userId = row[Users.id].value,
      username = row[Users.username],
      email = row[Users.email],
      displayName = row[Users.displayName],
      passwordHash = row[Users.passwordHash],
      deletedAt = row[Users.deletedAt],
    )
  }

  suspend fun createUser(registerRequest: CreateUserRequest): User = dbQuery {
    // Hashed once and reused for both the row and the returned `User`. This
    // used to call `hashPassword` twice, so the `User` handed back carried a
    // *second* hash that was never stored — different salt, same password, and
    // nothing that verifies against the database. Harmless today because login
    // re-reads the row, and a landmine the first time something checks a
    // candidate password against this object's `passwordHash`.
    //
    // Named `hashedPassword` rather than `passwordHash` on purpose: inside
    // `Users.insert { it[passwordHash] = ... }` the bare name `passwordHash`
    // resolves to this local rather than to the `Users.passwordHash` column,
    // and Exposed fails to compile rather than writing somewhere else quietly.
    val hashedPassword = PasswordHasher.hashPassword(registerRequest.password)

    val id = Users.insert {
      it[username] = registerRequest.username
      it[email] = registerRequest.email
      it[displayName] = registerRequest.displayName
      it[passwordHash] = hashedPassword
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
      passwordHash = hashedPassword
    )
  }

  suspend fun getUsers(
    organizationId: Int?,
    search: String?,
    limit: Int?,
    offset: Long?,
    sortBy: String?,
    sortOrder: String?,
    status: UserStatusFilter = UserStatusFilter.ACTIVE,
  ): PaginatedResponse<User> = dbQuery {
    val conditions = mutableListOf<Op<Boolean>>()
    when (status) {
      UserStatusFilter.ACTIVE -> conditions.add(activeCondition())
      UserStatusFilter.DEACTIVATED -> conditions.add(Users.deletedAt.isNotNull())
      UserStatusFilter.ALL -> {}
    }
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

  suspend fun getAllUsers(includeDeactivated: Boolean = false): List<User> = dbQuery {
    val query = if (includeDeactivated) Users.selectAll() else Users.selectAll().where { activeCondition() }
    query.map { toUser(it) }
  }

  suspend fun getUsersByOrganization(organizationId: Int, includeDeactivated: Boolean = false): List<User> = dbQuery {
    val userIds = UserOrganizations.selectAll()
      .where { UserOrganizations.organizationId eq organizationId }
      .map { it[UserOrganizations.userId] }
    val condition = if (includeDeactivated) {
      Users.id inList userIds
    } else {
      (Users.id inList userIds) and activeCondition()
    }
    Users.selectAll()
      .where { condition }
      .map { toUser(it) }
  }

  suspend fun deactivateUser(userId: Int): Boolean = dbQuery {
    Users.update({ (Users.id eq userId) and Users.deletedAt.isNull() }) {
      it[deletedAt] = OffsetDateTime.now()
    } > 0
  }

  suspend fun restoreUser(userId: Int): Boolean = dbQuery {
    Users.update({ (Users.id eq userId) and Users.deletedAt.isNotNull() }) {
      it[deletedAt] = null
    } > 0
  }

  suspend fun getUserById(userId: Int, includeDeactivated: Boolean = false): User = dbQuery {
    val condition = if (includeDeactivated) {
      Users.id eq userId
    } else {
      (Users.id eq userId) and activeCondition()
    }
    Users.selectAll()
      .where { condition }
      .mapNotNull { toUser(it) }
      .single()
  }

  suspend fun findUserById(userId: Int, includeDeactivated: Boolean = false): User? = dbQuery {
    val condition = if (includeDeactivated) {
      Users.id eq userId
    } else {
      (Users.id eq userId) and activeCondition()
    }
    Users.selectAll()
      .where { condition }
      .mapNotNull { toUser(it) }
      .singleOrNull()
  }

  suspend fun getUserByUsername(username: String, includeDeactivated: Boolean = false): User? = dbQuery {
    val condition = if (includeDeactivated) {
      Users.username eq username
    } else {
      (Users.username eq username) and activeCondition()
    }
    Users.selectAll()
      .where { condition }
      .mapNotNull { toUser(it) }
      .singleOrNull()
  }

  suspend fun getUserByEmail(email: String, includeDeactivated: Boolean = false): User? = dbQuery {
    val condition = if (includeDeactivated) {
      Users.email eq email
    } else {
      (Users.email eq email) and activeCondition()
    }
    Users.selectAll()
      .where { condition }
      .mapNotNull { toUser(it) }
      .singleOrNull()
  }

  suspend fun updateUser(userId: Int, updateUserRequest: UpdateUserRequest): User? =
    dbQuery {
      val updatedRows = Users.update({ (Users.id eq userId) and Users.deletedAt.isNull() }) {
        updateUserRequest.email?.let { email -> it[Users.email] = email }
        updateUserRequest.displayName?.let { displayName -> it[Users.displayName] = displayName }
      }
      if (updatedRows > 0) {
        findUserById(userId, includeDeactivated = false)
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
          contactInformation = it[Organizations.contactInformation],
          timezone = it[Organizations.timezone],
        )
      }
  }
}
