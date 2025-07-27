// frontend/src/api/CustomerService.ts

import { CustomerResponse, CreateCustomerRequest, UpdateCustomerRequest } from '../types/customers';
import { StatusResponse } from '../types/common';

export class CustomerService {
  // TODO: Implement get all customers
  static async getAllCustomers(): Promise<CustomerResponse[]> {
    console.log('Getting all customers');
    throw new Error('Not implemented');
  }

  // TODO: Implement get specific customer
  static async getCustomer(customerId: number): Promise<CustomerResponse> {
    console.log('Getting customer:', customerId);
    throw new Error('Not implemented');
  }

  // TODO: Implement create customer
  static async createCustomer(request: CreateCustomerRequest): Promise<CustomerResponse> {
    console.log('Creating customer:', request);
    throw new Error('Not implemented');
  }

  // TODO: Implement update customer
  static async updateCustomer(customerId: number, request: UpdateCustomerRequest): Promise<CustomerResponse> {
    console.log('Updating customer:', customerId, request);
    throw new Error('Not implemented');
  }

  // TODO: Implement delete customer
  static async deleteCustomer(customerId: number): Promise<StatusResponse> {
    console.log('Deleting customer:', customerId);
    throw new Error('Not implemented');
  }
}
