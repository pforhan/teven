package alphainterplanetary.teven.core.service

import alphainterplanetary.teven.core.security.UserPermissions
import io.ktor.util.AttributeKey

interface PermissionService {
  companion object {
    val key = AttributeKey<PermissionService>("PermissionService")
  }

  suspend fun getPermissions(callerId: Int): UserPermissions
}