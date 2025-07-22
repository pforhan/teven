
package com.teven.app.customer

import com.teven.api.model.common.StatusResponse
import com.teven.api.model.customer.CreateCustomerRequest
import com.teven.api.model.customer.UpdateCustomerRequest
import com.teven.service.customer.CustomerService
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import org.koin.ktor.ext.inject

fun Route.customerRoutes() {
    val customerService by inject<CustomerService>()

    route("/api/customers") {
        get {
            val customers = customerService.getAllCustomers()
            call.respond(HttpStatusCode.OK, customers)
        }

        get("/{customer_id}") {
            val customerId = call.parameters["customer_id"]?.toIntOrNull()
            if (customerId == null) {
                call.respondText("Invalid customer ID", status = HttpStatusCode.BadRequest)
                return@get
            }
            val customer = customerService.getCustomerById(customerId)
            if (customer != null) {
                call.respond(HttpStatusCode.OK, customer)
            } else {
                call.respond(HttpStatusCode.NotFound, "Customer not found")
            }
        }

        post {
            val createCustomerRequest = call.receive<CreateCustomerRequest>()
            val newCustomer = customerService.createCustomer(createCustomerRequest)
            call.respond(HttpStatusCode.Created, newCustomer)
        }

        put("/{customer_id}") {
            val customerId = call.parameters["customer_id"]?.toIntOrNull()
            if (customerId == null) {
                call.respondText("Invalid customer ID", status = HttpStatusCode.BadRequest)
                return@put
            }
            val updateCustomerRequest = call.receive<UpdateCustomerRequest>()
            if (customerService.updateCustomer(customerId, updateCustomerRequest)) {
                call.respond(HttpStatusCode.OK, "Customer with ID $customerId updated")
            } else {
                call.respond(HttpStatusCode.NotFound, "Customer not found or no changes applied")
            }
        }

        delete("/{customer_id}") {
            val customerId = call.parameters["customer_id"]?.toIntOrNull()
            if (customerId == null) {
                call.respondText("Invalid customer ID", status = HttpStatusCode.BadRequest)
                return@delete
            }
                        if (customerService.deleteCustomer(customerId)) {
                call.respond(HttpStatusCode.NoContent)
            } else {
                call.respond(HttpStatusCode.NotFound, "Customer not found")
            }
        }
    }
}
