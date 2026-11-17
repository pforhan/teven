package alphainterplanetary.teven.core.user

import java.time.OffsetDateTime

data class User(
  val userId: Int,
  val username: String,
  val email: String,
  val displayName: String,
  val passwordHash: String,
  val deletedAt: OffsetDateTime? = null,
)
