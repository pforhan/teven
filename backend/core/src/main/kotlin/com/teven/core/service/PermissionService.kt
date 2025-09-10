package com.teven.core.service

import com.teven.core.security.UserPermissions
import io.ktor.util.AttributeKey

interface PermissionService {
  companion object {
    val key = AttributeKey<PermissionService>("PermissionService")
  }

  suspend fun getPermissions(callerId: Int): UserPermissions
}