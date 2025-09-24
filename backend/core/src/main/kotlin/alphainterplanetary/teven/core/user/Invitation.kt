package alphainterplanetary.teven.core.user

import kotlinx.serialization.Serializable
import java.time.LocalDateTime

data class Invitation(
  val id: Int,
  val organizationId: Int,
  val roleId: Int,
  var roleName: String,
  val token: String,
  val expiresAt: LocalDateTime,
  val usedByUserId: Int?,
  val createdAt: LocalDateTime,
)