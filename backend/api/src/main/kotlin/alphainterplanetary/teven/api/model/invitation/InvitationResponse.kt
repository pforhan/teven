package alphainterplanetary.teven.api.model.invitation

import kotlinx.serialization.Serializable

@Serializable
data class InvitationResponse(
  val invitationId: Int,
  val organizationId: Int,
  val roleId: Int,
  val roleName: String,
  val token: String,
  val expiresAt: String,
  val usedByUserId: Int?,
  val createdAt: String,
)
