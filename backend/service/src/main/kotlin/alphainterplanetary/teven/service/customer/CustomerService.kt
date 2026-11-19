package alphainterplanetary.teven.service.customer

import alphainterplanetary.teven.api.model.common.PaginatedResponse
import alphainterplanetary.teven.api.model.customer.CreateCustomerRequest
import alphainterplanetary.teven.api.model.customer.CustomerResponse
import alphainterplanetary.teven.api.model.customer.UpdateCustomerRequest
import alphainterplanetary.teven.core.security.AuthContext
import alphainterplanetary.teven.core.security.AuthorizationException
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.data.customer.CustomerDao
import alphainterplanetary.teven.data.customer.CustomerStatusFilter
import io.ktor.http.HttpStatusCode

class CustomerService(private val customerDao: CustomerDao) {
  suspend fun getCustomers(
    authContext: AuthContext,
    organizationId: Int? = null,
    search: String? = null,
    limit: Int? = null,
    offset: Long? = null,
    sortBy: String? = null,
    sortOrder: String? = null,
    status: String? = null,
  ): PaginatedResponse<CustomerResponse> {
    val canViewGlobal = authContext.hasPermission(Permission.VIEW_CUSTOMERS_GLOBAL)
    val orgIdToUse = if (canViewGlobal) organizationId else authContext.organizationId

    val canRequestDeactivated =
      canViewGlobal ||
        authContext.hasPermission(Permission.MANAGE_CUSTOMERS_GLOBAL) ||
        authContext.hasPermission(Permission.MANAGE_CUSTOMERS_ORGANIZATION)

    val statusFilter = if (canRequestDeactivated) {
      when (status?.lowercase()) {
        "deactivated", "deleted", "inactive" -> CustomerStatusFilter.DEACTIVATED
        "all" -> CustomerStatusFilter.ALL
        else -> CustomerStatusFilter.ACTIVE
      }
    } else {
      CustomerStatusFilter.ACTIVE
    }

    return customerDao.getCustomers(
      organizationId = orgIdToUse,
      search = search,
      limit = limit,
      offset = offset,
      sortBy = sortBy,
      sortOrder = sortOrder,
      status = statusFilter,
    )
  }

  suspend fun getAllCustomers(authContext: AuthContext, organizationId: Int? = null): List<CustomerResponse> {
    val canViewGlobal = authContext.hasPermission(Permission.VIEW_CUSTOMERS_GLOBAL)
    val orgIdToUse = if (canViewGlobal) organizationId else authContext.organizationId

    return if (orgIdToUse != null) {
      customerDao.getAllCustomersByOrganization(orgIdToUse)
    } else {
      customerDao.getAllCustomers()
    }
  }

  suspend fun getCustomerById(authContext: AuthContext, customerId: Int): CustomerResponse? {
    val isGlobalViewer = authContext.hasPermission(Permission.VIEW_CUSTOMERS_GLOBAL)
    val isGlobalManager = authContext.hasPermission(Permission.MANAGE_CUSTOMERS_GLOBAL)
    val isOrgManager = authContext.hasPermission(Permission.MANAGE_CUSTOMERS_ORGANIZATION)
    val canViewDeactivated = isGlobalViewer || isGlobalManager || isOrgManager

    val customer = customerDao.getCustomerById(customerId, includeDeactivated = canViewDeactivated)
      ?: return null

    val sameOrg = customer.organization.organizationId == authContext.organizationId
    if (!isGlobalViewer && !sameOrg) return null

    if (customer.deletedAt != null) {
      val allowed = isGlobalViewer || isGlobalManager || (isOrgManager && sameOrg)
      if (!allowed) return null
    }

    return customer
  }

  suspend fun createCustomer(authContext: AuthContext, createCustomerRequest: CreateCustomerRequest): CustomerResponse {
    val organizationIdToUse = if (authContext.hasPermission(Permission.MANAGE_CUSTOMERS_GLOBAL)) {
      createCustomerRequest.organizationId
        ?: throw IllegalArgumentException("organizationId is required for MANAGE_CUSTOMERS_GLOBAL users")
    } else {
      authContext.organizationId
    }

    val requestWithOrgId = createCustomerRequest.copy(organizationId = organizationIdToUse)
    return customerDao.createCustomer(requestWithOrgId)
  }

  suspend fun updateCustomer(
    authContext: AuthContext,
    customerId: Int,
    updateCustomerRequest: UpdateCustomerRequest,
  ): CustomerResponse? {
    val customer = customerDao.getCustomerById(customerId, includeDeactivated = true)
      ?: return null
    if (customer.deletedAt != null) return null

    if (!authContext.hasPermission(Permission.MANAGE_CUSTOMERS_GLOBAL) &&
      customer.organization.organizationId != authContext.organizationId
    ) {
      throw IllegalAccessException("User not authorized to update customers outside their organization")
    }

    val requestWithOrgId = if (authContext.hasPermission(Permission.MANAGE_CUSTOMERS_GLOBAL)) {
      updateCustomerRequest
    } else {
      if (updateCustomerRequest.organizationId != null &&
        updateCustomerRequest.organizationId != customer.organization.organizationId
      ) {
        throw IllegalArgumentException("Non-MANAGE_CUSTOMERS_GLOBAL users cannot change customer organizationId")
      }
      updateCustomerRequest.copy(organizationId = customer.organization.organizationId)
    }

    return customerDao.updateCustomer(customerId, requestWithOrgId)
  }

  suspend fun deactivateCustomer(authContext: AuthContext, customerId: Int): Boolean {
    val customer = customerDao.getCustomerById(customerId, includeDeactivated = true)
      ?: return false
    if (!authContext.hasPermission(Permission.MANAGE_CUSTOMERS_GLOBAL) &&
      customer.organization.organizationId != authContext.organizationId
    ) {
      throw IllegalAccessException("User not authorized to delete customers outside their organization")
    }
    if (customer.deletedAt != null) return true
    return customerDao.deactivateCustomer(customerId)
  }

  suspend fun restoreCustomer(authContext: AuthContext, customerId: Int): CustomerResponse? {
    val customer = customerDao.getCustomerById(customerId, includeDeactivated = true)
      ?: return null
    val canManageGlobal = authContext.hasPermission(Permission.MANAGE_CUSTOMERS_GLOBAL)
    if (!canManageGlobal) {
      val canManageOrg = authContext.hasPermission(Permission.MANAGE_CUSTOMERS_ORGANIZATION)
      val sameOrg = canManageOrg && customer.organization.organizationId == authContext.organizationId
      if (!sameOrg) {
        throw AuthorizationException(HttpStatusCode.Forbidden, "Not authorized to restore this customer.")
      }
    }
    if (customer.deletedAt == null) return customer
    customerDao.restoreCustomer(customerId)
    return customerDao.getCustomerById(customerId, includeDeactivated = false)
  }

  // Backward-compatible name used by existing callers/routes; now performs deactivation.
  suspend fun deleteCustomer(authContext: AuthContext, customerId: Int): Boolean =
    deactivateCustomer(authContext, customerId)
}
