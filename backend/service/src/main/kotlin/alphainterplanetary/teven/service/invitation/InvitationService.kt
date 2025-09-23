package alphainterplanetary.teven.service.invitation

import alphainterplanetary.teven.data.invitation.InvitationDao
import alphainterplanetary.teven.core.user.Invitation
import java.time.LocalDateTime
import java.util.UUID

class InvitationService(private val invitationDao: InvitationDao) {

  suspend fun generateInvitation(
    organizationId: Int,
    roleId: Int,
    expiresAt: LocalDateTime? = null,
  ): Invitation {
    val token = UUID.randomUUID().toString()
    val expiration = expiresAt ?: LocalDateTime.now().plusDays(7) // Default to 7 days
    val invitationId = invitationDao.createInvitation(organizationId, roleId, token, expiration)
    return Invitation(
      id = invitationId,
      organizationId = organizationId,
      roleId = roleId,
      token = token,
      expiresAt = expiration,
      usedByUserId = null,
      createdAt = LocalDateTime.now()
    )
  }

  suspend fun validateInvitation(token: String): Invitation? {
    val invitation = invitationDao.getInvitationByToken(token)
    return if (invitation != null && invitation.expiresAt.isAfter(LocalDateTime.now()) && invitation.usedByUserId == null) {
      invitation
    } else {
      null
    }
  }

  suspend fun markInvitationAsUsed(token: String, userId: Int): Boolean {
    return invitationDao.markInvitationAsUsed(token, userId)
  }
}