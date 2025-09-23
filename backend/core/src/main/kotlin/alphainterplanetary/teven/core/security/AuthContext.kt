package alphainterplanetary.teven.core.security
data class AuthContext(
  val userId: Int,
  val organizationId: Int,
  val permissions: Set<Permission>,
) {
  fun hasPermission(permission: Permission): Boolean {
    return permissions.contains(permission)
  }
}
