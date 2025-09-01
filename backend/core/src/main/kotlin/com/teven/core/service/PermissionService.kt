package com.teven.core.service

import com.teven.core.security.UserPermissions

interface PermissionService {
    suspend fun getPermissions(callerId: Int): UserPermissions
}