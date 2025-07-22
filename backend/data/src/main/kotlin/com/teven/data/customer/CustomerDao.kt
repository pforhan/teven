
package com.teven.data.customer

import com.teven.api.model.customer.CreateCustomerRequest
import com.teven.api.model.customer.CustomerResponse
import com.teven.api.model.customer.UpdateCustomerRequest
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.select
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.transactions.transaction
import org.jetbrains.exposed.sql.update
import org.jetbrains.exposed.sql.deleteWhere
import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq

class CustomerDao {
    private fun toCustomerResponse(row: ResultRow): CustomerResponse {
        return CustomerResponse(
            customerId = row[Customers.id].value,
            name = row[Customers.name],
            contactInformation = row[Customers.contactInformation]
        )
    }

    fun getAllCustomers(): List<CustomerResponse> {
        return transaction {
            Customers.selectAll().map { toCustomerResponse(it) }
        }
    }

    fun getCustomerById(customerId: Int): CustomerResponse? {
        return transaction {
            Customers.select { Customers.id eq customerId }
                .mapNotNull { toCustomerResponse(it) }
                .singleOrNull()
        }
    }

    fun createCustomer(createCustomerRequest: CreateCustomerRequest): CustomerResponse {
        return transaction {
            val id = Customers.insert {
                it[name] = createCustomerRequest.name
                it[contactInformation] = createCustomerRequest.contactInformation
            } get Customers.id

            CustomerResponse(
                customerId = id.value,
                name = createCustomerRequest.name,
                contactInformation = createCustomerRequest.contactInformation
            )
        }
    }

    fun updateCustomer(customerId: Int, updateCustomerRequest: UpdateCustomerRequest): Boolean {
        return transaction {
            Customers.update({ Customers.id eq customerId }) {
                updateCustomerRequest.name?.let { name -> it[Customers.name] = name }
                updateCustomerRequest.contactInformation?.let { contactInformation -> it[Customers.contactInformation] = contactInformation }
            } > 0
        }
    }

    fun deleteCustomer(customerId: Int): Boolean {
        return transaction {
            Customers.deleteWhere { Customers.id eq customerId } > 0
        }
    }
}
