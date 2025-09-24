package alphainterplanetary.teven.data.invitation

import alphainterplanetary.teven.core.user.Invitation
import alphainterplanetary.teven.data.dbQuery
import org.jetbrains.exposed.v1.core.and
import org.jetbrains.exposed.v1.core.eq
import org.jetbrains.exposed.v1.core.greaterEq
import org.jetbrains.exposed.v1.core.isNull
import org.jetbrains.exposed.v1.jdbc.deleteWhere
import org.jetbrains.exposed.v1.jdbc.insert
import org.jetbrains.exposed.v1.jdbc.selectAll
import org.jetbrains.exposed.v1.jdbc.update
import java.time.LocalDateTime

class InvitationDao {

  suspend fun createInvitation(
    organizationId: Int,
    roleId: Int,
    token: String,
    expiresAt: LocalDateTime,
  ): Int = dbQuery {
    (Invitations.insert {
      it[Invitations.organizationId] = organizationId
      it[Invitations.roleId] = roleId
      it[Invitations.token] = token
      it[Invitations.expiresAt] = expiresAt
      it[usedByUserId] = null
    } get Invitations.id).value
  }

  suspend fun getInvitationByToken(token: String): Invitation? = dbQuery {
    Invitations.selectAll()
      .map { Invitation(
        id = it[Invitations.id].value,
        organizationId = it[Invitations.organizationId].value,
        roleId = it[Invitations.roleId].value,
        roleName = "", // Placeholder, will be set in service
        token = it[Invitations.token],
        expiresAt = it[Invitations.expiresAt],
        usedByUserId = it[Invitations.usedByUserId]?.value,
        createdAt = it[Invitations.createdAt],
      ) }
      .singleOrNull()
  }

  suspend fun markInvitationAsUsed(token: String, userId: Int): Boolean = dbQuery {
    Invitations.update({ Invitations.token eq token }) {
      it[usedByUserId] = userId
    } > 0
  }

  suspend fun getUnusedInvitations(organizationId: Int): List<Invitation> = dbQuery {
    Invitations.selectAll()
      .where {
        Invitations.organizationId eq organizationId and Invitations.usedByUserId.isNull() and (Invitations.expiresAt greaterEq LocalDateTime.now())
      }
      .map { Invitation(
        id = it[Invitations.id].value,
        organizationId = it[Invitations.organizationId].value,
        roleId = it[Invitations.roleId].value,
        roleName = "", // Placeholder, will be set in service
        token = it[Invitations.token],
        expiresAt = it[Invitations.expiresAt],
        usedByUserId = it[Invitations.usedByUserId]?.value,
        createdAt = it[Invitations.createdAt],
      ) }
  }

  suspend fun deleteInvitation(invitationId: Int): Boolean = dbQuery {
    Invitations.deleteWhere { Invitations.id eq invitationId } > 0
  }
}

