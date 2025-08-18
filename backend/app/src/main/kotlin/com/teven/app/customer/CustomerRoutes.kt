package com.teven.app.customer

import com.teven.api.model.common.StatusResponse
import com.teven.api.model.customer.CreateCustomerRequest
import com.teven.api.model.customer.UpdateCustomerRequest
import com.teven.auth.withPermission
import com.teven.core.security.Permission
import com.teven.service.customer.CustomerService
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

fun Route.customerRoutes() {
  val customerService by inject<CustomerService>()

  route("/api/customers") {
    withPermission(Permission.MANAGE_CUSTOMERS_ORGANIZATION) {
      post {
        val createCustomerRequest = call.receive<CreateCustomerRequest>()
        val newCustomer = customerService.createCustomer(createCustomerRequest)
        call.respond(HttpStatusCode.Created, newCustomer)
      }

      put("/{customer_id}") {
        val customerId = call.parameters["customer_id"]?.toIntOrNull()
        if (customerId == null) {
          call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid customer ID"))
          return@put
        }
        val updateCustomerRequest = call.receive<UpdateCustomerRequest>()
        if (customerService.updateCustomer(customerId, updateCustomerRequest)) {
          call.respond(HttpStatusCode.OK, StatusResponse("Customer with ID $customerId updated"))
        } else {
          call.respond(
            HttpStatusCode.NotFound,
            StatusResponse("Customer not found or no changes applied")
          )
        }
      }

      delete("/{customer_id}") {
        val customerId = call.parameters["customer_id"]?.toIntOrNull()
        if (customerId == null) {
          call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid customer ID"))
          return@delete
        }
        if (customerService.deleteCustomer(customerId)) {
          call.respond(HttpStatusCode.NoContent)
        } else {
          call.respond(HttpStatusCode.NotFound, StatusResponse("Customer not found"))
        }
      }
    }

    withPermission(Permission.VIEW_CUSTOMERS_ORGANIZATION) {
      get {
        val customers = customerService.getAllCustomers()
        call.respond(HttpStatusCode.OK, customers)
      }

      get("/{customer_id}") {
        val customerId = call.parameters["customer_id"]?.toIntOrNull()
        if (customerId == null) {
          call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid customer ID"))
          return@get
        }
        val customer = customerService.getCustomerById(customerId)
        if (customer != null) {
          call.respond(HttpStatusCode.OK, customer)
        } else {
          call.respond(HttpStatusCode.NotFound, StatusResponse("Customer not found"))
        }
      }
    }
  }
}
