package alphainterplanetary.teven.data.customer

import alphainterplanetary.teven.api.model.common.PaginatedResponse
import alphainterplanetary.teven.api.model.customer.CreateCustomerRequest
import alphainterplanetary.teven.api.model.customer.CustomerResponse
import alphainterplanetary.teven.api.model.customer.UpdateCustomerRequest
import alphainterplanetary.teven.api.model.organization.OrganizationResponse
import alphainterplanetary.teven.core.Pagination
import alphainterplanetary.teven.data.dbQuery
import alphainterplanetary.teven.data.organization.Organizations
import org.jetbrains.exposed.v1.core.Op
import org.jetbrains.exposed.v1.core.ResultRow
import org.jetbrains.exposed.v1.core.SortOrder
import org.jetbrains.exposed.v1.core.and
import org.jetbrains.exposed.v1.core.eq
import org.jetbrains.exposed.v1.core.isNotNull
import org.jetbrains.exposed.v1.core.isNull
import org.jetbrains.exposed.v1.core.like
import org.jetbrains.exposed.v1.core.lowerCase
import org.jetbrains.exposed.v1.jdbc.insert
import org.jetbrains.exposed.v1.jdbc.selectAll
import org.jetbrains.exposed.v1.jdbc.update
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter

enum class CustomerStatusFilter {
  ACTIVE,
  DEACTIVATED,
  ALL,
}

class CustomerDao {
  private fun activeCondition(): Op<Boolean> = Customers.deletedAt.isNull()

  private fun toCustomerResponse(row: ResultRow): CustomerResponse {
    val organization =
      Organizations.selectAll().where { Organizations.id eq row[Customers.organizationId] }.single()
        .let {
          OrganizationResponse(
            organizationId = it[Organizations.id].value,
            name = it[Organizations.name],
            contactInformation = it[Organizations.contactInformation],
            timezone = it[Organizations.timezone],
          )
        }
    return CustomerResponse(
      customerId = row[Customers.id],
      name = row[Customers.name],
      phone = row[Customers.phone],
      address = row[Customers.address],
      latitude = row[Customers.latitude],
      longitude = row[Customers.longitude],
      formattedAddress = row[Customers.formattedAddress],
      notes = row[Customers.notes],
      deletedAt = row[Customers.deletedAt]?.format(DateTimeFormatter.ISO_OFFSET_DATE_TIME),
      organization = organization,
    )
  }

  suspend fun getCustomers(
    organizationId: Int?,
    search: String?,
    limit: Int?,
    offset: Long?,
    sortBy: String?,
    sortOrder: String?,
    status: CustomerStatusFilter = CustomerStatusFilter.ACTIVE,
  ): PaginatedResponse<CustomerResponse> = dbQuery {
    val conditions = mutableListOf<Op<Boolean>>()
    when (status) {
      CustomerStatusFilter.ACTIVE -> conditions.add(activeCondition())
      CustomerStatusFilter.DEACTIVATED -> conditions.add(Customers.deletedAt.isNotNull())
      CustomerStatusFilter.ALL -> {}
    }
    organizationId?.let { conditions.add(Customers.organizationId eq it) }
    search?.let { conditions.add(Customers.name.lowerCase() like "%${it.lowercase()}%") }

    val query = if (conditions.isEmpty()) {
      Customers.selectAll()
    } else {
      val combinedCondition = conditions.reduce { acc, op -> acc and op }
      Customers.selectAll().where { combinedCondition }
    }

    val total = query.count()

    val sort = if (sortOrder == "desc") SortOrder.DESC else SortOrder.ASC
    when (sortBy) {
      "name" -> query.orderBy(Customers.name, sort)
      else -> query.orderBy(Customers.id, sort)
    }

    val effectiveOffset = offset ?: 0
    val effectiveLimit = Pagination.effectiveLimit(limit)
    query.offset(effectiveOffset)
    query.limit(effectiveLimit)

    val customers = query.map { toCustomerResponse(it) }

    PaginatedResponse(
      items = customers,
      total = total,
      offset = effectiveOffset,
      limit = effectiveLimit,
    )
  }

  suspend fun getAllCustomers(includeDeactivated: Boolean = false): List<CustomerResponse> = dbQuery {
    val query = if (includeDeactivated) {
      Customers.selectAll()
    } else {
      Customers.selectAll().where { activeCondition() }
    }
    query.map { toCustomerResponse(it) }
  }

  suspend fun getAllCustomersByOrganization(
    organizationId: Int,
    includeDeactivated: Boolean = false,
  ): List<CustomerResponse> = dbQuery {
    val condition = if (includeDeactivated) {
      Customers.organizationId eq organizationId
    } else {
      (Customers.organizationId eq organizationId) and activeCondition()
    }
    Customers.selectAll()
      .where { condition }
      .map { toCustomerResponse(it) }
  }

  suspend fun getCustomerById(
    customerId: Int,
    includeDeactivated: Boolean = false,
  ): CustomerResponse? = dbQuery {
    val condition = if (includeDeactivated) {
      Customers.id eq customerId
    } else {
      (Customers.id eq customerId) and activeCondition()
    }
    Customers.selectAll()
      .where { condition }
      .mapNotNull { toCustomerResponse(it) }
      .singleOrNull()
  }

  suspend fun findCustomerById(
    customerId: Int,
    includeDeactivated: Boolean = false,
  ): CustomerResponse? = getCustomerById(customerId, includeDeactivated)

  suspend fun createCustomer(createCustomerRequest: CreateCustomerRequest): CustomerResponse =
    dbQuery {
      val id = Customers.insert {
        it[name] = createCustomerRequest.name
        it[phone] = createCustomerRequest.phone
        it[address] = createCustomerRequest.address
        it[latitude] = createCustomerRequest.latitude
        it[longitude] = createCustomerRequest.longitude
        it[formattedAddress] = createCustomerRequest.formattedAddress
        it[notes] = createCustomerRequest.notes
        it[organizationId] = createCustomerRequest.organizationId!!
      } get Customers.id

      toCustomerResponse(Customers.selectAll().where { Customers.id eq id }.single())
    }

  suspend fun updateCustomer(
    customerId: Int,
    updateCustomerRequest: UpdateCustomerRequest,
  ): CustomerResponse? = dbQuery {
    val updated = Customers.update({ (Customers.id eq customerId) and Customers.deletedAt.isNull() }) {
      updateCustomerRequest.name?.let { name -> it[Customers.name] = name }
      updateCustomerRequest.phone?.let { phone -> it[Customers.phone] = phone }
      updateCustomerRequest.address?.let { address -> it[Customers.address] = address }
      updateCustomerRequest.latitude?.let { latitude -> it[Customers.latitude] = latitude }
      updateCustomerRequest.longitude?.let { longitude -> it[Customers.longitude] = longitude }
      updateCustomerRequest.formattedAddress?.let { formattedAddress ->
        it[Customers.formattedAddress] = formattedAddress
      }
      updateCustomerRequest.notes?.let { notes -> it[Customers.notes] = notes }
      updateCustomerRequest.organizationId?.let { organizationId ->
        it[Customers.organizationId] = organizationId
      }
    } > 0
    if (!updated) return@dbQuery null

    getCustomerById(customerId, includeDeactivated = false)
  }

  suspend fun deactivateCustomer(customerId: Int): Boolean = dbQuery {
    Customers.update({ (Customers.id eq customerId) and Customers.deletedAt.isNull() }) {
      it[deletedAt] = OffsetDateTime.now()
    } > 0
  }

  suspend fun restoreCustomer(customerId: Int): Boolean = dbQuery {
    Customers.update({ (Customers.id eq customerId) and Customers.deletedAt.isNotNull() }) {
      it[deletedAt] = null
    } > 0
  }

  suspend fun deleteCustomer(customerId: Int): Boolean = deactivateCustomer(customerId)
}
