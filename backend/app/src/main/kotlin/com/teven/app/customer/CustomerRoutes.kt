package com.teven.app.customer

import com.teven.api.model.common.failure
import com.teven.api.model.common.success
import com.teven.api.model.customer.CreateCustomerRequest
import com.teven.api.model.customer.UpdateCustomerRequest
import com.teven.auth.withPermission
import com.teven.core.security.Permission.MANAGE_CUSTOMERS_ORGANIZATION
import com.teven.core.security.Permission.VIEW_CUSTOMERS_ORGANIZATION
import com.teven.service.customer.CustomerService
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.*
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
    withPermission(MANAGE_CUSTOMERS_ORGANIZATION) {
      post {
        val createCustomerRequest = call.receive<CreateCustomerRequest>()
        val newCustomer = customerService.createCustomer(createCustomerRequest)
        call.respond(HttpStatusCode.Created, success(newCustomer))
      }

      put("/{customer_id}") {
        val customerId = call.parameters["customer_id"]?.toIntOrNull()
        if (customerId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid customer ID"))
          return@put
        }
        val updateCustomerRequest = call.receive<UpdateCustomerRequest>()
        if (customerService.updateCustomer(customerId, updateCustomerRequest)) {
          call.respond(HttpStatusCode.OK, success("Customer with ID $customerId updated"))
        } else {
          call.respond(
            HttpStatusCode.NotFound,
            failure("Customer not found or no changes applied")
          )
        }
      }

      delete("/{customer_id}") {
        val customerId = call.parameters["customer_id"]?.toIntOrNull()
        if (customerId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid customer ID"))
          return@delete
        }
        if (customerService.deleteCustomer(customerId)) {
          call.respond(HttpStatusCode.NoContent)
        } else {
          call.respond(HttpStatusCode.NotFound, failure("Customer not found"))
        }
      }
    }

    withPermission(VIEW_CUSTOMERS_ORGANIZATION) {
      get {
        val customers = customerService.getAllCustomers()
        call.respond(HttpStatusCode.OK, success(customers))
      }

      get("/{customer_id}") {
        val customerId = call.parameters["customer_id"]?.toIntOrNull()
        if (customerId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid customer ID"))
          return@get
        }
        val customer = customerService.getCustomerById(customerId)
        if (customer != null) {
          call.respond(HttpStatusCode.OK, success(customer))
        } else {
          call.respond(HttpStatusCode.NotFound, failure("Customer not found"))
        }
      }
    }
  }
}