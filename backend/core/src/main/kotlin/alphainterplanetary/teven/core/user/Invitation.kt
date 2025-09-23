package alphainterplanetary.teven.core.user

import java.time.LocalDateTime

data class Invitation(
  val id: Int,
  val organizationId: Int,
  val roleId: Int,
  val token: String,
  val expiresAt: LocalDateTime,
  val usedByUserId: Int?,
  val createdAt: LocalDateTime,
)