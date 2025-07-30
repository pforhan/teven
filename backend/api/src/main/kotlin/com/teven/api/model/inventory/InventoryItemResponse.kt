package com.teven.api.model.inventory

import kotlinx.serialization.Serializable

@Serializable
data class InventoryItemResponse(
  val inventoryId: Int,
  val name: String,
  val description: String,
  val quantity: Int,
)
