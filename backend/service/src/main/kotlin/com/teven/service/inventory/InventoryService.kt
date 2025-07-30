package com.teven.service.inventory

import com.teven.api.model.inventory.CreateInventoryItemRequest
import com.teven.api.model.inventory.InventoryItemResponse
import com.teven.api.model.inventory.TrackInventoryUsageRequest
import com.teven.api.model.inventory.UpdateInventoryItemRequest
import com.teven.data.inventory.InventoryDao

class InventoryService(private val inventoryDao: InventoryDao) {
  suspend fun getAllInventoryItems(): List<InventoryItemResponse> {
    return inventoryDao.getAllInventoryItems()
  }

  suspend fun getInventoryItemById(inventoryId: Int): InventoryItemResponse? {
    return inventoryDao.getInventoryItemById(inventoryId)
  }

  suspend fun createInventoryItem(createInventoryItemRequest: CreateInventoryItemRequest): InventoryItemResponse {
    return inventoryDao.createInventoryItem(createInventoryItemRequest)
  }

  suspend fun updateInventoryItem(
    inventoryId: Int,
    updateInventoryItemRequest: UpdateInventoryItemRequest,
  ): Boolean {
    return inventoryDao.updateInventoryItem(inventoryId, updateInventoryItemRequest)
  }

  suspend fun deleteInventoryItem(inventoryId: Int): Boolean {
    return inventoryDao.deleteInventoryItem(inventoryId)
  }

  suspend fun trackInventoryUsage(
    inventoryId: Int,
    trackInventoryUsageRequest: TrackInventoryUsageRequest,
  ): Boolean {
    return inventoryDao.trackInventoryUsage(inventoryId, trackInventoryUsageRequest)
  }
}
