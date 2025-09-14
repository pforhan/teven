package alphainterplanetary.teven.service.customer

import alphainterplanetary.teven.api.model.customer.CreateCustomerRequest
import alphainterplanetary.teven.api.model.customer.CustomerResponse
import alphainterplanetary.teven.api.model.customer.UpdateCustomerRequest
import alphainterplanetary.teven.core.security.AuthContext
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.data.customer.CustomerDao

class CustomerService(private val customerDao: CustomerDao) {
  suspend fun getAllCustomers(authContext: AuthContext, organizationId: Int? = null): List<CustomerResponse> {
    val orgIdToUse = if (authContext.hasPermission(Permission.VIEW_CUSTOMERS_GLOBAL)) {
      organizationId
    } else {
      authContext.organizationId
    }

    return if (orgIdToUse != null) {
      customerDao.getAllCustomersByOrganization(orgIdToUse)
    } else {
      customerDao.getAllCustomers()
    }
  }

  suspend fun getCustomerById(authContext: AuthContext, customerId: Int): CustomerResponse? {
    val customer = customerDao.getCustomerById(customerId)

    return if (customer != null && !authContext.hasPermission(Permission.VIEW_CUSTOMERS_GLOBAL) && customer.organization.organizationId != authContext.organizationId) {
      null // Not found or not authorized
    } else {
      customer
    }
  }

  suspend fun createCustomer(authContext: AuthContext, createCustomerRequest: CreateCustomerRequest): CustomerResponse {
    val organizationIdToUse = if (authContext.hasPermission(Permission.MANAGE_CUSTOMERS_GLOBAL)) {
      createCustomerRequest.organizationId
        ?: throw IllegalArgumentException("organizationId is required for MANAGE_CUSTOMERS_GLOBAL users")
    } else {
      authContext.organizationId
    }

    // Create a new request with the determined organizationId
    val requestWithOrgId = createCustomerRequest.copy(organizationId = organizationIdToUse)

    return customerDao.createCustomer(requestWithOrgId)
  }

  suspend fun updateCustomer(
    authContext: AuthContext,
    customerId: Int,
    updateCustomerRequest: UpdateCustomerRequest,
  ): Boolean {
    // Check if the customer belongs to the user's organization or if the user has MANAGE_CUSTOMERS_GLOBAL
    val customer = customerDao.getCustomerById(customerId)
      ?: return false // Customer not found

    if (!authContext.hasPermission(Permission.MANAGE_CUSTOMERS_GLOBAL) && customer.organization.organizationId != authContext.organizationId) {
      throw IllegalAccessException("User not authorized to update customers outside their organization")
    }

    // If MANAGE_CUSTOMERS_GLOBAL, allow organizationId to be updated, otherwise ensure it's not changed
    val requestWithOrgId = if (authContext.hasPermission(Permission.MANAGE_CUSTOMERS_GLOBAL)) {
      updateCustomerRequest
    } else {
      if (updateCustomerRequest.organizationId != null && updateCustomerRequest.organizationId != customer.organization.organizationId) {
        throw IllegalArgumentException("Non-MANAGE_CUSTOMERS_GLOBAL users cannot change customer organizationId")
      }
      updateCustomerRequest.copy(organizationId = customer.organization.organizationId)
    }

    return customerDao.updateCustomer(customerId, requestWithOrgId)
  }

  suspend fun deleteCustomer(authContext: AuthContext, customerId: Int): Boolean {
    val customer = customerDao.getCustomerById(customerId)
      ?: return false // Customer not found

    if (!authContext.hasPermission(Permission.MANAGE_CUSTOMERS_GLOBAL) && customer.organization.organizationId != authContext.organizationId) {
      throw IllegalAccessException("User not authorized to delete customers outside their organization")
    }
    return customerDao.deleteCustomer(customerId)
  }
}
