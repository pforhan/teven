package com.teven.app.inventory

import com.teven.api.model.common.failure
import com.teven.api.model.common.success
import com.teven.api.model.inventory.CreateInventoryItemRequest
import com.teven.api.model.inventory.TrackInventoryUsageRequest
import com.teven.api.model.inventory.UpdateInventoryItemRequest
import com.teven.auth.withPermission
import com.teven.core.security.AuthContext
import com.teven.core.security.Permission.MANAGE_INVENTORY_GLOBAL
import com.teven.core.security.Permission.MANAGE_INVENTORY_ORGANIZATION
import com.teven.core.security.Permission.VIEW_INVENTORY_GLOBAL
import com.teven.core.security.Permission.VIEW_INVENTORY_ORGANIZATION
import com.teven.core.security.UserPrincipal
import com.teven.service.inventory.InventoryService
import io.ktor.http.HttpStatusCode
import io.ktor.server.auth.principal
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
    // Create Inventory Item
    withPermission(MANAGE_INVENTORY_ORGANIZATION, MANAGE_INVENTORY_GLOBAL) {
      post {
        val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
        val createInventoryItemRequest = call.receive<CreateInventoryItemRequest>()
        val newInventoryItem = inventoryService.createInventoryItem(authContext, createInventoryItemRequest)
        call.respond(HttpStatusCode.Created, success(newInventoryItem))
      }
    }

    // Update Inventory Item
    withPermission(MANAGE_INVENTORY_ORGANIZATION, MANAGE_INVENTORY_GLOBAL) {
      put("{inventory_id}") {
        val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
        val inventoryId = call.parameters["inventory_id"]?.toIntOrNull()
        if (inventoryId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid inventory ID"))
          return@put
        }
        val updateInventoryItemRequest = call.receive<UpdateInventoryItemRequest>()
        if (inventoryService.updateInventoryItem(authContext, inventoryId, updateInventoryItemRequest)) {
          call.respond(HttpStatusCode.OK, success("Inventory item with ID $inventoryId updated"))
        } else {
          call.respond(
            HttpStatusCode.NotFound,
            failure("Inventory item not found or no changes applied")
          )
        }
      }
    }

    // Delete Inventory Item
    withPermission(MANAGE_INVENTORY_ORGANIZATION, MANAGE_INVENTORY_GLOBAL) {
      delete("{inventory_id}") {
        val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
        val inventoryId = call.parameters["inventory_id"]?.toIntOrNull()
        if (inventoryId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid inventory ID"))
          return@delete
        }
        if (inventoryService.deleteInventoryItem(authContext, inventoryId)) {
          call.respond(HttpStatusCode.NoContent)
        } else {
          call.respond(HttpStatusCode.NotFound, failure("Inventory item not found"))
        }
      }
    }

    // View Inventory Items
    withPermission(VIEW_INVENTORY_ORGANIZATION, VIEW_INVENTORY_GLOBAL) {
      get {
        val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
        val inventoryItems = inventoryService.getAllInventoryItems(authContext)
        call.respond(HttpStatusCode.OK, success(inventoryItems))
      }

      get("{inventory_id}") {
        val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
        val inventoryId = call.parameters["inventory_id"]?.toIntOrNull()
        if (inventoryId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid inventory ID"))
          return@get
        }
        val inventoryItem = inventoryService.getInventoryItemById(authContext, inventoryId)
        if (inventoryItem != null) {
          call.respond(HttpStatusCode.OK, success(inventoryItem))
        } else {
          call.respond(HttpStatusCode.NotFound, failure("Inventory item not found"))
        }
      }
    }

    // Track Inventory Usage
    withPermission(MANAGE_INVENTORY_ORGANIZATION) {
      post("{inventory_id}/usage") {
        val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
        val inventoryId = call.parameters["inventory_id"]?.toIntOrNull()
        if (inventoryId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid inventory ID"))
          return@post
        }
        val trackInventoryUsageRequest = call.receive<TrackInventoryUsageRequest>()
        if (inventoryService.trackInventoryUsage(authContext, inventoryId, trackInventoryUsageRequest)) {
          call.respond(HttpStatusCode.OK, success("OK"))
        } else {
          call.respond(
            HttpStatusCode.InternalServerError,
            failure("Failed to track inventory usage")
          )
        }
      }
    }
  }
}

private fun UserPrincipal.toAuthContext(): AuthContext {
  return AuthContext(userId, organizationId, permissions)
}
