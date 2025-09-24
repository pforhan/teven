package alphainterplanetary.teven.service.invitation

import alphainterplanetary.teven.data.invitation.InvitationDao
import alphainterplanetary.teven.core.user.Invitation
import alphainterplanetary.teven.core.service.RoleService
import alphainterplanetary.teven.api.model.invitation.InvitationResponse
import java.time.LocalDateTime
import java.util.UUID

class InvitationService(private val invitationDao: InvitationDao, private val roleService: RoleService) {

  private fun Invitation.toInvitationResponse(): InvitationResponse {
    return InvitationResponse(
      invitationId = id,
      organizationId = organizationId,
      roleId = roleId,
      roleName = roleName,
      token = token,
      expiresAt = expiresAt.toString(),
      usedByUserId = usedByUserId,
      createdAt = createdAt.toString(),
    )
  }

  suspend fun generateInvitation(
    organizationId: Int,
    roleId: Int,
    expiresAt: LocalDateTime? = null,
  ): InvitationResponse {
    val token = UUID.randomUUID().toString()
    val expiration = expiresAt ?: LocalDateTime.now().plusDays(7) // Default to 7 days
    val invitationId = invitationDao.createInvitation(organizationId, roleId, token, expiration)
    val role = roleService.getRoleById(roleId) ?: throw IllegalArgumentException("Role not found")
    return Invitation(
      id = invitationId,
      organizationId = organizationId,
      roleId = roleId,
      roleName = role.roleName,
      token = token,
      expiresAt = expiration,
      usedByUserId = null,
      createdAt = LocalDateTime.now()
    ).toInvitationResponse()
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

  suspend fun getUnusedInvitations(organizationId: Int): List<InvitationResponse> {
    val invitations = invitationDao.getUnusedInvitations(organizationId)
    val roles = roleService.getAllRoles().associateBy { it.roleId }
    return invitations.map { invitation ->
      invitation.copy(roleName = roles[invitation.roleId]?.roleName ?: "Unknown")
    }.map { it.toInvitationResponse() }
  }

  suspend fun deleteInvitation(invitationId: Int): Boolean {
    return invitationDao.deleteInvitation(invitationId)
  }
}