
package com.teven.service.inventory

import com.teven.api.model.inventory.CreateInventoryItemRequest
import com.teven.api.model.inventory.InventoryItemResponse
import com.teven.api.model.inventory.TrackInventoryUsageRequest
import com.teven.api.model.inventory.UpdateInventoryItemRequest
import com.teven.data.inventory.InventoryDao

class InventoryService(private val inventoryDao: InventoryDao) {
    fun getAllInventoryItems(): List<InventoryItemResponse> {
        return inventoryDao.getAllInventoryItems()
    }

    fun getInventoryItemById(inventoryId: Int): InventoryItemResponse? {
        return inventoryDao.getInventoryItemById(inventoryId)
    }

    fun createInventoryItem(createInventoryItemRequest: CreateInventoryItemRequest): InventoryItemResponse {
        return inventoryDao.createInventoryItem(createInventoryItemRequest)
    }

    fun updateInventoryItem(inventoryId: Int, updateInventoryItemRequest: UpdateInventoryItemRequest): Boolean {
        return inventoryDao.updateInventoryItem(inventoryId, updateInventoryItemRequest)
    }

    fun deleteInventoryItem(inventoryId: Int): Boolean {
        return inventoryDao.deleteInventoryItem(inventoryId)
    }

    fun trackInventoryUsage(inventoryId: Int, trackInventoryUsageRequest: TrackInventoryUsageRequest): Boolean {
        return inventoryDao.trackInventoryUsage(inventoryId, trackInventoryUsageRequest)
    }
}
