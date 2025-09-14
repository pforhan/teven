package alphainterplanetary.teven.core.user

data class User(
  val userId: Int,
  val username: String,
  val email: String,
  val displayName: String,
  val passwordHash: String,
)
