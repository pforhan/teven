package com.teven.api.model.inventory

import kotlinx.serialization.Serializable

@Serializable
data class CreateInventoryItemRequest(
  val name: String,
  val description: String,
  val quantity: Int,
  val organizationId: Int? = null,
)
