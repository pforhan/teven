package alphainterplanetary.teven.data.invitation

import alphainterplanetary.teven.core.user.Invitation
import alphainterplanetary.teven.data.dbQuery
import alphainterplanetary.teven.data.role.Roles
import alphainterplanetary.teven.data.organization.Organizations
import org.jetbrains.exposed.v1.core.SortOrder
import org.jetbrains.exposed.v1.core.and
import org.jetbrains.exposed.v1.core.eq
import org.jetbrains.exposed.v1.core.greaterEq
import org.jetbrains.exposed.v1.core.isNull
import org.jetbrains.exposed.v1.jdbc.deleteWhere
import org.jetbrains.exposed.v1.jdbc.insert
import org.jetbrains.exposed.v1.jdbc.selectAll
import org.jetbrains.exposed.v1.jdbc.update
import java.time.Clock
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneOffset

class InvitationDao(private val clock: Clock) {

  suspend fun createInvitation(
    organizationId: Int,
    roleId: Int,
    token: String,
    expiresAt: Instant,
    note: String?,
  ): Invitation = dbQuery {
    val result = Invitations.insert {
      it[Invitations.organizationId] = organizationId
      it[Invitations.roleId] = roleId
      it[Invitations.token] = token
      it[Invitations.expiresAt] = OffsetDateTime.ofInstant(expiresAt, ZoneOffset.UTC)
      it[usedByUserId] = null
      it[Invitations.note] = note
    }
    Invitation(
      id = result[Invitations.id].value,
      organizationId = result[Invitations.organizationId].value,
      organizationName = "", // Placeholder, will be set in service
      roleId = result[Invitations.roleId].value,
      roleName = "", // Placeholder, will be set in service
      token = result[Invitations.token],
      expiresAt = result[Invitations.expiresAt].toInstant(),
      usedByUserId = null,
      createdAt = result[Invitations.createdAt].toInstant(),
      note = result[Invitations.note],
    )
  }

  suspend fun hasOrganizationId(invitationId: Int, organizationId: Int): Boolean = dbQuery {
    Invitations.selectAll()
      .where { (Invitations.id eq invitationId) and (Invitations.organizationId eq organizationId) }
      .count() == 1L
  }

  suspend fun getInvitationByToken(token: String): Invitation? = dbQuery {
    (Invitations innerJoin Roles innerJoin Organizations).selectAll()
      .where { Invitations.token eq token }
      .map {
        Invitation(
          id = it[Invitations.id].value,
          organizationId = it[Invitations.organizationId].value,
          organizationName = it[Organizations.name],
          roleId = it[Invitations.roleId].value,
          roleName = it[Roles.roleName],
          token = it[Invitations.token],
          expiresAt = it[Invitations.expiresAt].toInstant(),
          usedByUserId = it[Invitations.usedByUserId]?.value,
          createdAt = it[Invitations.createdAt].toInstant(),
          note = it[Invitations.note],
        )
      }
      .singleOrNull()
  }

  suspend fun markInvitationAsUsed(token: String, userId: Int): Boolean = dbQuery {
    Invitations.update({ Invitations.token eq token }) {
      it[usedByUserId] = userId
    } > 0
  }

  suspend fun getUnusedInvitations(
    organizationId: Int?,
    sortBy: String? = null,
    sortOrder: String? = null,
  ): List<Invitation> = dbQuery {
    val baseCondition = Invitations.usedByUserId.isNull() and
      (Invitations.expiresAt greaterEq OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC))
    val condition = organizationId?.let { baseCondition and (Invitations.organizationId eq it) } ?: baseCondition

    val query = (Invitations innerJoin Roles innerJoin Organizations)
      .selectAll()
      .where { condition }

    val sort = if (sortOrder == "desc") SortOrder.DESC else SortOrder.ASC
    when (sortBy) {
      "organization", "organizationName" -> query.orderBy(Organizations.name, sort)
      "role", "roleName" -> query.orderBy(Roles.roleName, sort)
      "expiresAt" -> query.orderBy(Invitations.expiresAt, sort)
      "createdAt" -> query.orderBy(Invitations.createdAt, sort)
      else -> query.orderBy(Invitations.createdAt, SortOrder.DESC)
    }

    query.map {
      Invitation(
        id = it[Invitations.id].value,
        organizationId = it[Invitations.organizationId].value,
        organizationName = it[Organizations.name],
        roleId = it[Invitations.roleId].value,
        roleName = it[Roles.roleName],
        token = it[Invitations.token],
        expiresAt = it[Invitations.expiresAt].toInstant(),
        usedByUserId = it[Invitations.usedByUserId]?.value,
        createdAt = it[Invitations.createdAt].toInstant(),
        note = it[Invitations.note],
      )
    }
  }

  suspend fun deleteInvitation(invitationId: Int): Boolean = dbQuery {
    Invitations.deleteWhere { Invitations.id eq invitationId } > 0
  }
}

