package alphainterplanetary.teven.core.user

import java.time.Instant

data class Invitation(
  val id: Int,
  val organizationId: Int,
  val organizationName: String,
  val roleId: Int,
  var roleName: String,
  val token: String,
  val expiresAt: Instant,
  val usedByUserId: Int?,
  val createdAt: Instant,
  val note: String?,
)

enum class DeleteInvitationStatus {
  SUCCESS,
  NOT_FOUND,
  FORBIDDEN,
}
