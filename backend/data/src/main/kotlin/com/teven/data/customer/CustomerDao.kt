
package com.teven.data.customer

import com.teven.api.model.customer.CreateCustomerRequest
import com.teven.api.model.customer.CustomerResponse
import com.teven.api.model.customer.UpdateCustomerRequest
import com.teven.data.dbQuery
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.select
import org.jetbrains.exposed.sql.selectAll
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

    suspend fun getAllCustomers(): List<CustomerResponse> = dbQuery {
        Customers.selectAll().map { toCustomerResponse(it) }
    }

    suspend fun getCustomerById(customerId: Int): CustomerResponse? = dbQuery {
        Customers.select { Customers.id eq customerId }
            .mapNotNull { toCustomerResponse(it) }
            .singleOrNull()
    }

    suspend fun createCustomer(createCustomerRequest: CreateCustomerRequest): CustomerResponse = dbQuery {
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

    suspend fun updateCustomer(customerId: Int, updateCustomerRequest: UpdateCustomerRequest): Boolean = dbQuery {
        Customers.update({ Customers.id eq customerId }) {
            updateCustomerRequest.name?.let { name -> it[Customers.name] = name }
            updateCustomerRequest.contactInformation?.let { contactInformation -> it[Customers.contactInformation] = contactInformation }
        } > 0
    }

    suspend fun deleteCustomer(customerId: Int): Boolean = dbQuery {
        Customers.deleteWhere { Customers.id eq customerId } > 0
    }
}
