
package com.teven.api.model.auth

import kotlinx.serialization.Serializable

@Serializable
data class LoginResponse(
    val token: String,
    val userId: Int,
    val username: String,
    val displayName: String,
    val role: String
)
