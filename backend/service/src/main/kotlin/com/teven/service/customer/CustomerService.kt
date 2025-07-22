
package com.teven.service.customer

import com.teven.api.model.customer.CreateCustomerRequest
import com.teven.api.model.customer.CustomerResponse
import com.teven.api.model.customer.UpdateCustomerRequest
import com.teven.data.customer.CustomerDao

class CustomerService(private val customerDao: CustomerDao) {
    fun getAllCustomers(): List<CustomerResponse> {
        return customerDao.getAllCustomers()
    }

    fun getCustomerById(customerId: Int): CustomerResponse? {
        return customerDao.getCustomerById(customerId)
    }

    fun createCustomer(createCustomerRequest: CreateCustomerRequest): CustomerResponse {
        return customerDao.createCustomer(createCustomerRequest)
    }

    fun updateCustomer(customerId: Int, updateCustomerRequest: UpdateCustomerRequest): Boolean {
        return customerDao.updateCustomer(customerId, updateCustomerRequest)
    }

    fun deleteCustomer(customerId: Int): Boolean {
        return customerDao.deleteCustomer(customerId)
    }
}
