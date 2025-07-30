package com.teven.data.inventory

import com.teven.api.model.inventory.CreateInventoryItemRequest
import com.teven.api.model.inventory.InventoryItemResponse
import com.teven.api.model.inventory.TrackInventoryUsageRequest
import com.teven.api.model.inventory.UpdateInventoryItemRequest
import com.teven.data.dbQuery
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
import org.jetbrains.exposed.sql.deleteWhere
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.select
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.update

class InventoryDao {
  private fun toInventoryItemResponse(row: ResultRow): InventoryItemResponse {
    return InventoryItemResponse(
      inventoryId = row[InventoryItems.id].value,
      name = row[InventoryItems.name],
      description = row[InventoryItems.description],
      quantity = row[InventoryItems.quantity]
    )
  }

  suspend fun getAllInventoryItems(): List<InventoryItemResponse> = dbQuery {
    InventoryItems.selectAll().map { toInventoryItemResponse(it) }
  }

  suspend fun getInventoryItemById(inventoryId: Int): InventoryItemResponse? = dbQuery {
    InventoryItems.select { InventoryItems.id eq inventoryId }
      .mapNotNull { toInventoryItemResponse(it) }
      .singleOrNull()
  }

  suspend fun createInventoryItem(createInventoryItemRequest: CreateInventoryItemRequest): InventoryItemResponse =
    dbQuery {
      val id = InventoryItems.insert {
        it[name] = createInventoryItemRequest.name
        it[description] = createInventoryItemRequest.description
        it[quantity] = createInventoryItemRequest.quantity
      } get InventoryItems.id

      InventoryItemResponse(
        inventoryId = id.value,
        name = createInventoryItemRequest.name,
        description = createInventoryItemRequest.description,
        quantity = createInventoryItemRequest.quantity
      )
    }

  suspend fun updateInventoryItem(
    inventoryId: Int,
    updateInventoryItemRequest: UpdateInventoryItemRequest,
  ): Boolean = dbQuery {
    InventoryItems.update({ InventoryItems.id eq inventoryId }) {
      updateInventoryItemRequest.name?.let { name -> it[InventoryItems.name] = name }
      updateInventoryItemRequest.description?.let { description ->
        it[InventoryItems.description] = description
      }
      updateInventoryItemRequest.quantity?.let { quantity ->
        it[InventoryItems.quantity] = quantity
      }
    } > 0
  }

  suspend fun deleteInventoryItem(inventoryId: Int): Boolean = dbQuery {
    return@dbQuery InventoryItems.deleteWhere { InventoryItems.id eq inventoryId } > 0
  }

  suspend fun trackInventoryUsage(
    inventoryId: Int,
    trackInventoryUsageRequest: TrackInventoryUsageRequest,
  ): Boolean = dbQuery {
    InventoryUsage.insert {
      it[InventoryUsage.inventoryId] = inventoryId
      it[InventoryUsage.eventId] = trackInventoryUsageRequest.eventId
      it[InventoryUsage.quantityUsed] = trackInventoryUsageRequest.quantity
      it[InventoryUsage.usageDate] = java.time.LocalDate.now().toString() // Use current date
    }
    true
  }
}
