
package com.teven.api.model.role

import kotlinx.serialization.Serializable

@Serializable
data class RoleResponse(
    val roleId: Int,
    val roleName: String,
    val permissions: List<String>
)
