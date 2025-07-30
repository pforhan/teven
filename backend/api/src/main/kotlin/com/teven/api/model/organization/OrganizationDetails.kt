package com.teven.api.model.organization

import kotlinx.serialization.Serializable

@Serializable
data class OrganizationDetails(
  val organizationId: Int,
  val name: String,
  val contactInformation: String,
  // Add other relevant organization details as needed
)
