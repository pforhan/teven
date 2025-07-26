
package com.teven.api.model.auth

import kotlinx.serialization.Serializable

@Serializable
data class UpdateUserRequest(
    val email: String? = null,
    val displayName: String? = null,
    val staffDetails: UpdateStaffDetails? = null
)

@Serializable
data class UpdateStaffDetails(
    val contactInformation: String? = null,
    val skills: List<String>? = null,
    val phoneNumber: String? = null,
    val dateOfBirth: String? = null // ISO 8601 date string
)
