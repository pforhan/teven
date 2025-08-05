import type { CustomerResponse, CreateCustomerRequest, UpdateCustomerRequest } from '../types/customers';
import type { StatusResponse } from '../types/common';
import { apiClient } from './apiClient';

export class CustomerService {
  static async getAllCustomers(nameFilter?: string, sortByName?: 'asc' | 'desc'): Promise<CustomerResponse[]> {
    const url = new URL('/api/customers', window.location.origin);
    if (nameFilter) {
      url.searchParams.append('name', nameFilter);
    }
    if (sortByName) {
      url.searchParams.append('sortByName', sortByName);
    }
    return apiClient(url.toString());
  }

  static async getCustomer(customerId: number): Promise<CustomerResponse> {
    return apiClient(`/api/customers/${customerId}`);
  }

  static async createCustomer(request: CreateCustomerRequest): Promise<CustomerResponse> {
    return apiClient('/api/customers', {
      method: 'POST',
      body: JSON.stringify(request),
    });
  }

  static async updateCustomer(customerId: number, request: UpdateCustomerRequest): Promise<CustomerResponse> {
    return apiClient(`/api/customers/${customerId}`, {
      method: 'PUT',
      body: JSON.stringify(request),
    });
  }

  static async deleteCustomer(customerId: number): Promise<StatusResponse> {
    return apiClient(`/api/customers/${customerId}`, { method: 'DELETE' });
  }
}
