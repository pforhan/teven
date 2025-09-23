package alphainterplanetary.teven.data.invitation

import alphainterplanetary.teven.core.user.Invitation
import alphainterplanetary.teven.data.dbQuery
import org.jetbrains.exposed.v1.core.eq
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
      .where { Invitations.token eq token }
      .map { Invitation(
        id = it[Invitations.id].value,
        organizationId = it[Invitations.organizationId].value,
        roleId = it[Invitations.roleId].value,
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
}

