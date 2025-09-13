package com.teven.app.customer

import com.teven.api.model.common.failure
import com.teven.api.model.common.success
import com.teven.api.model.customer.CreateCustomerRequest
import com.teven.api.model.customer.UpdateCustomerRequest
import com.teven.auth.withPermission
import com.teven.core.security.AuthContext
import com.teven.core.security.Permission.MANAGE_CUSTOMERS_GLOBAL
import com.teven.core.security.Permission.MANAGE_CUSTOMERS_ORGANIZATION
import com.teven.core.security.Permission.VIEW_CUSTOMERS_GLOBAL
import com.teven.core.security.Permission.VIEW_CUSTOMERS_ORGANIZATION
import com.teven.core.security.UserPrincipal
import com.teven.service.customer.CustomerService
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.call
import io.ktor.server.auth.principal
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.*
import org.koin.ktor.ext.inject

fun Route.customerRoutes() {
  val customerService by inject<CustomerService>()

  route("/api/customers") {
    // Create Customer
    withPermission(MANAGE_CUSTOMERS_ORGANIZATION, MANAGE_CUSTOMERS_GLOBAL) {
      post {
        val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
        val createCustomerRequest = call.receive<CreateCustomerRequest>()
        val newCustomer = customerService.createCustomer(authContext, createCustomerRequest)
        call.respond(HttpStatusCode.Created, success(newCustomer))
      }
    }

    // Update Customer
    withPermission(MANAGE_CUSTOMERS_ORGANIZATION, MANAGE_CUSTOMERS_GLOBAL) {
      put("{customer_id}") {
        val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
        val customerId = call.parameters["customer_id"]?.toIntOrNull()
        if (customerId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid customer ID"))
          return@put
        }
        val updateCustomerRequest = call.receive<UpdateCustomerRequest>()
        if (customerService.updateCustomer(authContext, customerId, updateCustomerRequest)) {
          call.respond(HttpStatusCode.OK, success("Customer with ID $customerId updated"))
        } else {
          call.respond(
            HttpStatusCode.NotFound,
            failure("Customer not found or no changes applied")
          )
        }
      }
    }

    // Delete Customer
    withPermission(MANAGE_CUSTOMERS_ORGANIZATION, MANAGE_CUSTOMERS_GLOBAL) {
      delete("{customer_id}") {
        val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
        val customerId = call.parameters["customer_id"]?.toIntOrNull()
        if (customerId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid customer ID"))
          return@delete
        }
        if (customerService.deleteCustomer(authContext, customerId)) {
          call.respond(HttpStatusCode.NoContent)
        } else {
          call.respond(HttpStatusCode.NotFound, failure("Customer not found"))
        }
      }
    }

    // View Customers
    withPermission(VIEW_CUSTOMERS_ORGANIZATION, VIEW_CUSTOMERS_GLOBAL) {
      get {
        val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
        val customers = customerService.getAllCustomers(authContext)
        call.respond(HttpStatusCode.OK, success(customers))
      }

      get("{customer_id}") {
        val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
        val customerId = call.parameters["customer_id"]?.toIntOrNull()
        if (customerId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid customer ID"))
          return@get
        }
        val customer = customerService.getCustomerById(authContext, customerId)
        if (customer != null) {
          call.respond(HttpStatusCode.OK, success(customer))
        } else {
          call.respond(HttpStatusCode.NotFound, failure("Customer not found"))
        }
      }
    }
  }
}

private fun UserPrincipal.toAuthContext(): AuthContext {
  return AuthContext(userId, organizationId, permissions)
}