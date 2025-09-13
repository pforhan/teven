package com.teven.data.customer

import com.teven.api.model.customer.CreateCustomerRequest
import com.teven.api.model.customer.CustomerResponse
import com.teven.api.model.customer.UpdateCustomerRequest
import com.teven.api.model.organization.OrganizationResponse
import com.teven.data.dbQuery
import com.teven.data.organization.Organizations
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
import org.jetbrains.exposed.sql.deleteWhere
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.select
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.update

class CustomerDao {
  private fun toCustomerResponse(row: ResultRow): CustomerResponse {
    val organization = Organizations.select { Organizations.id eq row[Customers.organizationId] }.single().let {
      OrganizationResponse(
        organizationId = it[Organizations.id].value,
        name = it[Organizations.name],
        contactInformation = it[Organizations.contactInformation]
      )
    }
    return CustomerResponse(
      customerId = row[Customers.id],
      name = row[Customers.name],
      phone = row[Customers.phone],
      address = row[Customers.address],
      notes = row[Customers.notes],
      organization = organization,
    )
  }

  suspend fun getAllCustomers(): List<CustomerResponse> = dbQuery {
    Customers.selectAll().map { toCustomerResponse(it) }
  }

  suspend fun getAllCustomersByOrganization(organizationId: Int): List<CustomerResponse> = dbQuery {
    Customers.select { Customers.organizationId eq organizationId }.map { toCustomerResponse(it) }
  }

  suspend fun getCustomerById(customerId: Int): CustomerResponse? = dbQuery {
    Customers.select { Customers.id eq customerId }
      .mapNotNull { toCustomerResponse(it) }
      .singleOrNull()
  }

  suspend fun createCustomer(createCustomerRequest: CreateCustomerRequest): CustomerResponse =
    dbQuery {
      val id = Customers.insert {
        it[name] = createCustomerRequest.name
        it[phone] = createCustomerRequest.phone
        it[address] = createCustomerRequest.address
        it[notes] = createCustomerRequest.notes
        it[organizationId] = createCustomerRequest.organizationId!!
      } get Customers.id

      CustomerResponse(
        customerId = id,
        name = createCustomerRequest.name,
        phone = createCustomerRequest.phone,
        address = createCustomerRequest.address,
        notes = createCustomerRequest.notes,
        organization = Organizations.select { Organizations.id eq createCustomerRequest.organizationId!! }.single().let {
          OrganizationResponse(
            organizationId = it[Organizations.id].value,
            name = it[Organizations.name],
            contactInformation = it[Organizations.contactInformation]
          )
        },
      )
    }

  suspend fun updateCustomer(
    customerId: Int,
    updateCustomerRequest: UpdateCustomerRequest,
  ): Boolean = dbQuery {
    Customers.update({ Customers.id eq customerId }) {
      updateCustomerRequest.name?.let { name -> it[Customers.name] = name }
      updateCustomerRequest.phone?.let { phone -> it[Customers.phone] = phone }
      updateCustomerRequest.address?.let { address -> it[Customers.address] = address }
      updateCustomerRequest.notes?.let { notes -> it[Customers.notes] = notes }
      updateCustomerRequest.organizationId?.let { organizationId -> it[Customers.organizationId] = organizationId!! }
    } > 0
  }

  suspend fun deleteCustomer(customerId: Int): Boolean = dbQuery {
    Customers.deleteWhere { Customers.id eq customerId } > 0
  }
}
