package alphainterplanetary.teven.service.invitation

import alphainterplanetary.teven.api.model.invitation.AcceptInvitationRequest
import alphainterplanetary.teven.api.model.invitation.InvitationResponse
import alphainterplanetary.teven.api.model.invitation.ValidateInvitationResponse
import alphainterplanetary.teven.core.security.AuthContext
import alphainterplanetary.teven.core.security.Permission.MANAGE_INVITATIONS_GLOBAL
import alphainterplanetary.teven.core.service.RoleService
import alphainterplanetary.teven.core.service.UserService
import alphainterplanetary.teven.core.user.AcceptInvitationResponse
import alphainterplanetary.teven.core.user.DeleteInvitationStatus
import alphainterplanetary.teven.core.user.DeleteInvitationStatus.FORBIDDEN
import alphainterplanetary.teven.core.user.DeleteInvitationStatus.NOT_FOUND
import alphainterplanetary.teven.core.user.DeleteInvitationStatus.SUCCESS
import alphainterplanetary.teven.core.user.Invitation
import alphainterplanetary.teven.data.invitation.InvitationDao
import alphainterplanetary.teven.service.organization.OrganizationService
import java.time.LocalDateTime
import java.util.UUID

class InvitationService(
  private val invitationDao: InvitationDao,
  private val roleService: RoleService,
  private val userService: UserService,
  private val organizationService: OrganizationService,
) {

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
      note = note,
    )
  }

  suspend fun generateInvitation(
    organizationId: Int,
    roleId: Int,
    expiresAt: LocalDateTime? = null,
    note: String? = null,
  ): InvitationResponse {
    val role = roleService.getRoleById(roleId) ?: throw IllegalArgumentException("Role not found")
    if (role.roleName !in listOf("Organizer", "Staff")) {
      throw IllegalArgumentException("Invitations can only be created for Organizer or Staff roles")
    }

    val organization = organizationService.getOrganizationById(organizationId)
      ?: throw IllegalArgumentException("Organization not found")

    val token = UUID.randomUUID().toString()
    val expiration = expiresAt ?: LocalDateTime.now().plusDays(7) // Default to 7 days
    val invitation = invitationDao.createInvitation(organizationId, roleId, token, expiration, note)
    return invitation.copy(
      roleName = role.roleName,
      organizationName = organization.name
    ).toInvitationResponse()
  }

  suspend fun validateInvitation(token: String): ValidateInvitationResponse? {
    val invitation = invitationDao.getInvitationByToken(token)
    return if (invitation != null && invitation.expiresAt.isAfter(LocalDateTime.now()) && invitation.usedByUserId == null) {
      ValidateInvitationResponse(
        organizationId = invitation.organizationId,
        organizationName = invitation.organizationName,
        roleName = invitation.roleName,
      )
    } else {
      null
    }
  }

  suspend fun acceptInvitation(request: AcceptInvitationRequest): AcceptInvitationResponse {
    val invitation = invitationDao.getInvitationByToken(request.token)
      ?: return AcceptInvitationResponse(success = false, message = "Invalid or expired invitation token.")

    if (invitation.expiresAt.isBefore(LocalDateTime.now())) {
      return AcceptInvitationResponse(success = false, message = "Invitation has expired.")
    }

    if (invitation.usedByUserId != null) {
      return AcceptInvitationResponse(success = false, message = "Invitation has already been used.")
    }

    // Check if username or email already exists
    if (userService.getUserByUsername(request.username) != null) {
      return AcceptInvitationResponse(success = false, message = "Username already taken.")
    }
    if (userService.getUserByEmail(request.email) != null) {
      return AcceptInvitationResponse(success = false, message = "Email already registered.")
    }

    // Create the user
    val userId = userService.createUserFromInvitation(request, invitation)

    // Mark invitation as used
    invitationDao.markInvitationAsUsed(request.token, userId)

    return AcceptInvitationResponse(success = true, message = "Invitation accepted and user created.")
  }

  suspend fun getUnusedInvitations(authContext: AuthContext): List<InvitationResponse> {
    val organizationId =
      if (authContext.hasPermission(MANAGE_INVITATIONS_GLOBAL)) null else authContext.organizationId
    val invitations = invitationDao.getUnusedInvitations(organizationId)

    val roles = roleService.getAllRoles().associateBy { it.roleId }
    val organizations = organizationService.getAllOrganizations().associateBy { it.organizationId }

    return invitations.map { invitation ->
      invitation.copy(
        roleName = roles[invitation.roleId]?.roleName ?: "Unknown",
        organizationName = organizations[invitation.organizationId]?.name ?: "Unknown"
      )
    }.map { it.toInvitationResponse() }
  }

  /**
   * If the logged in user has global permission, or the invitation is for the user's
   * organization, attempt the delete.  Otherwise return FORBIDDEN.
   */
  suspend fun deleteInvitation(
    invitationId: Int,
    authContext: AuthContext,
  ): DeleteInvitationStatus = if (authContext.hasPermission(MANAGE_INVITATIONS_GLOBAL) ||
    invitationDao.hasOrganizationId(invitationId, authContext.organizationId)
  ) {
    if (invitationDao.deleteInvitation(invitationId)) {
      SUCCESS
    } else {
      NOT_FOUND
    }
  }
  else FORBIDDEN
}