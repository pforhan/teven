
package com.teven.api.model.auth

import kotlinx.serialization.Serializable

@Serializable
data class UserDetailsResponse(
    val userId: Int,
    val username: String,
    val email: String,
    val role: String,
    val staffDetails: StaffDetails? // Nullable if user is not staff
)

@Serializable
data class StaffDetails(
    val contactInformation: String,
    val skills: List<String>,
    val hoursWorked: Int,
    val phoneNumber: String,
    val dateOfBirth: String // ISO 8601 date string
)
