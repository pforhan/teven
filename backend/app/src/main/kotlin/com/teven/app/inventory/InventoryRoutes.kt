package com.teven.app.inventory

import com.teven.api.model.common.StatusResponse
import com.teven.api.model.inventory.CreateInventoryItemRequest
import com.teven.api.model.inventory.TrackInventoryUsageRequest
import com.teven.api.model.inventory.UpdateInventoryItemRequest
import com.teven.service.inventory.InventoryService
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.call
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.delete
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.put
import io.ktor.server.routing.route
import org.koin.ktor.ext.inject

fun Route.inventoryRoutes() {
  val inventoryService by inject<InventoryService>()

  route("/api/inventory") {
    get {
      val inventoryItems = inventoryService.getAllInventoryItems()
      call.respond(HttpStatusCode.OK, inventoryItems)
    }

    get("/{inventory_id}") {
      val inventoryId = call.parameters["inventory_id"]?.toIntOrNull()
      if (inventoryId == null) {
        call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid inventory ID"))
        return@get
      }
      val inventoryItem = inventoryService.getInventoryItemById(inventoryId)
      if (inventoryItem != null) {
        call.respond(HttpStatusCode.OK, inventoryItem)
      } else {
        call.respond(HttpStatusCode.NotFound, StatusResponse("Inventory item not found"))
      }
    }

    post {
      val createInventoryItemRequest = call.receive<CreateInventoryItemRequest>()
      val newInventoryItem = inventoryService.createInventoryItem(createInventoryItemRequest)
      call.respond(HttpStatusCode.Created, newInventoryItem)
    }

    put("/{inventory_id}") {
      val inventoryId = call.parameters["inventory_id"]?.toIntOrNull()
      if (inventoryId == null) {
        call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid inventory ID"))
        return@put
      }
      val updateInventoryItemRequest = call.receive<UpdateInventoryItemRequest>()
      if (inventoryService.updateInventoryItem(inventoryId, updateInventoryItemRequest)) {
        call.respond(
          HttpStatusCode.OK,
          StatusResponse("Inventory item with ID $inventoryId updated")
        )
      } else {
        call.respond(
          HttpStatusCode.NotFound,
          StatusResponse("Inventory item not found or no changes applied")
        )
      }
    }

    delete("/{inventory_id}") {
      val inventoryId = call.parameters["inventory_id"]?.toIntOrNull()
      if (inventoryId == null) {
        call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid inventory ID"))
        return@delete
      }
      if (inventoryService.deleteInventoryItem(inventoryId)) {
        call.respond(HttpStatusCode.NoContent)
      } else {
        call.respond(HttpStatusCode.NotFound, StatusResponse("Inventory item not found"))
      }
    }

    post("/{inventory_id}/usage") {
      val inventoryId = call.parameters["inventory_id"]?.toIntOrNull()
      if (inventoryId == null) {
        call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid inventory ID"))
        return@post
      }
      val trackInventoryUsageRequest = call.receive<TrackInventoryUsageRequest>()
      if (inventoryService.trackInventoryUsage(inventoryId, trackInventoryUsageRequest)) {
        call.respond(HttpStatusCode.OK, StatusResponse("OK"))
      } else {
        call.respond(
          HttpStatusCode.InternalServerError,
          StatusResponse("Failed to track inventory usage")
        )
      }
    }
  }
}
