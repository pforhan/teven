package alphainterplanetary.teven.app.customer

import alphainterplanetary.teven.api.model.common.failure
import alphainterplanetary.teven.api.model.common.success
import alphainterplanetary.teven.api.model.customer.CreateCustomerRequest
import alphainterplanetary.teven.api.model.customer.UpdateCustomerRequest
import alphainterplanetary.teven.app.requireAuthContext
import alphainterplanetary.teven.auth.withPermission
import alphainterplanetary.teven.core.security.AuthContext
import alphainterplanetary.teven.core.security.Permission.MANAGE_CUSTOMERS_GLOBAL
import alphainterplanetary.teven.core.security.Permission.MANAGE_CUSTOMERS_ORGANIZATION
import alphainterplanetary.teven.core.security.Permission.VIEW_CUSTOMERS_GLOBAL
import alphainterplanetary.teven.core.security.Permission.VIEW_CUSTOMERS_ORGANIZATION
import alphainterplanetary.teven.service.customer.CustomerService
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

fun Route.customerRoutes() {
  val customerService by inject<CustomerService>()

  route("/api/customers") {
    // Create Customer
    withPermission(MANAGE_CUSTOMERS_ORGANIZATION, MANAGE_CUSTOMERS_GLOBAL) {
      post {
        val authContext = requireAuthContext()
        val createCustomerRequest = call.receive<CreateCustomerRequest>()
        val newCustomer = customerService.createCustomer(authContext, createCustomerRequest)
        call.respond(HttpStatusCode.Created, success(newCustomer))
      }
    }

    // Update Customer
    withPermission(MANAGE_CUSTOMERS_ORGANIZATION, MANAGE_CUSTOMERS_GLOBAL) {
      put("{customer_id}") {
        val authContext = requireAuthContext()
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
        val authContext = requireAuthContext()
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
        val authContext = requireAuthContext()
        val organizationId = call.request.queryParameters["organizationId"]?.toIntOrNull()
        val search = call.request.queryParameters["search"]
        val limit = call.request.queryParameters["limit"]?.toIntOrNull()
        val offset = call.request.queryParameters["offset"]?.toLongOrNull()
        val sortBy = call.request.queryParameters["sortBy"]
        val sortOrder = call.request.queryParameters["sortOrder"]

        val customers = customerService.getCustomers(
          authContext = authContext,
          organizationId = organizationId,
          search = search,
          limit = limit,
          offset = offset,
          sortBy = sortBy,
          sortOrder = sortOrder
        )
        call.respond(HttpStatusCode.OK, success(customers))
      }

      get("{customer_id}") {
        val authContext = call.principal<AuthContext>()!!
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