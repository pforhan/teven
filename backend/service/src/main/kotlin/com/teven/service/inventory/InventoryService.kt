package com.teven.service.inventory

import com.teven.api.model.inventory.CreateInventoryItemRequest
import com.teven.api.model.inventory.InventoryItemResponse
import com.teven.api.model.inventory.TrackInventoryUsageRequest
import com.teven.api.model.inventory.UpdateInventoryItemRequest
import com.teven.core.security.AuthContext
import com.teven.core.security.Permission
import com.teven.data.inventory.InventoryDao

class InventoryService(private val inventoryDao: InventoryDao) {
  suspend fun getAllInventoryItems(authContext: AuthContext): List<InventoryItemResponse> {
    return if (authContext.hasPermission(Permission.VIEW_INVENTORY_GLOBAL)) {
      inventoryDao.getAllInventoryItems()
    } else {
      inventoryDao.getAllInventoryItemsByOrganization(authContext.organizationId)
    }
  }

  suspend fun getInventoryItemById(authContext: AuthContext, inventoryId: Int): InventoryItemResponse? {
    val inventoryItem = inventoryDao.getInventoryItemById(inventoryId)

    return if (inventoryItem != null && !authContext.hasPermission(Permission.VIEW_INVENTORY_GLOBAL) && inventoryItem.organization.organizationId != authContext.organizationId) {
      null // Not found or not authorized
    } else {
      inventoryItem
    }
  }

  suspend fun createInventoryItem(authContext: AuthContext, createInventoryItemRequest: CreateInventoryItemRequest): InventoryItemResponse {
    val organizationIdToUse = if (authContext.hasPermission(Permission.MANAGE_INVENTORY_GLOBAL)) {
      createInventoryItemRequest.organizationId
        ?: throw IllegalArgumentException("organizationId is required for MANAGE_INVENTORY_GLOBAL users")
    } else {
      authContext.organizationId
    }

    // Create a new request with the determined organizationId
    val requestWithOrgId = createInventoryItemRequest.copy(organizationId = organizationIdToUse)

    return inventoryDao.createInventoryItem(requestWithOrgId)
  }

  suspend fun updateInventoryItem(
    authContext: AuthContext,
    inventoryId: Int,
    updateInventoryItemRequest: UpdateInventoryItemRequest,
  ): Boolean {
    // Check if the inventory item belongs to the user's organization or if the user has MANAGE_INVENTORY_GLOBAL
    val inventoryItem = inventoryDao.getInventoryItemById(inventoryId)
      ?: return false // Inventory item not found

    if (!authContext.hasPermission(Permission.MANAGE_INVENTORY_GLOBAL) && inventoryItem.organization.organizationId != authContext.organizationId) {
      throw IllegalAccessException("User not authorized to update inventory items outside their organization")
    }

    // If MANAGE_INVENTORY_GLOBAL, allow organizationId to be updated, otherwise ensure it's not changed
    val requestWithOrgId = if (authContext.hasPermission(Permission.MANAGE_INVENTORY_GLOBAL)) {
      updateInventoryItemRequest
    } else {
      if (updateInventoryItemRequest.organizationId != null && updateInventoryItemRequest.organizationId != inventoryItem.organization.organizationId) {
        throw IllegalArgumentException("Non-MANAGE_INVENTORY_GLOBAL users cannot change inventory item organizationId")
      }
      updateInventoryItemRequest.copy(organizationId = inventoryItem.organization.organizationId)
    }

    return inventoryDao.updateInventoryItem(inventoryId, requestWithOrgId)
  }

  suspend fun deleteInventoryItem(authContext: AuthContext, inventoryId: Int): Boolean {
    val inventoryItem = inventoryDao.getInventoryItemById(inventoryId)
      ?: return false // Inventory item not found

    if (!authContext.hasPermission(Permission.MANAGE_INVENTORY_GLOBAL) && inventoryItem.organization.organizationId != authContext.organizationId) {
      throw IllegalAccessException("User not authorized to delete inventory items outside their organization")
    }
    return inventoryDao.deleteInventoryItem(inventoryId)
  }

  suspend fun trackInventoryUsage(
    authContext: AuthContext,
    inventoryId: Int,
    trackInventoryUsageRequest: TrackInventoryUsageRequest,
  ): Boolean {
    val inventoryItem = inventoryDao.getInventoryItemById(inventoryId)
      ?: throw IllegalArgumentException("Inventory item not found")

    if (!authContext.hasPermission(Permission.MANAGE_INVENTORY_ORGANIZATION) && inventoryItem.organization.organizationId != authContext.organizationId) {
      throw IllegalAccessException("User not authorized to track inventory usage for items outside their organization")
    }
    return inventoryDao.trackInventoryUsage(inventoryId, trackInventoryUsageRequest)
  }
}
