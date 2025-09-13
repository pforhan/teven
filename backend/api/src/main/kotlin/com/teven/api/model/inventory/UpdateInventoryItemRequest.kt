package com.teven.api.model.inventory

import kotlinx.serialization.Serializable

@Serializable
data class UpdateInventoryItemRequest(
  val name: String? = null,
  val description: String? = null,
  val quantity: Int? = null,
  val organizationId: Int? = null,
)
