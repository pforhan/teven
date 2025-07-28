package com.teven.api.model.organization

import kotlinx.serialization.Serializable

@Serializable
data class CreateOrganizationRequest(
    val name: String,
    val contactInformation: String
)
