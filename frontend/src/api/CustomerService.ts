// frontend/src/api/CustomerService.ts

import type { CustomerResponse, CreateCustomerRequest, UpdateCustomerRequest } from '../types/customers';
import type { StatusResponse } from '../types/common';
import { AuthService } from './AuthService';

export class CustomerService {
  static async getAllCustomers(nameFilter?: string, sortByName?: 'asc' | 'desc'): Promise<CustomerResponse[]> {
    const url = new URL('/api/customers', window.location.origin);
    if (nameFilter) {
      url.searchParams.append('name', nameFilter);
    }
    if (sortByName) {
      url.searchParams.append('sortByName', sortByName);
    }

    const response = await fetch(url.toString(), {
      method: 'GET',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to fetch customers');
    }
    return response.json();
  }

  static async getCustomer(customerId: number): Promise<CustomerResponse> {
    const response = await fetch(`/api/customers/${customerId}`, {
      method: 'GET',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to fetch customer');
    }
    return response.json();
  }

  static async createCustomer(request: CreateCustomerRequest): Promise<CustomerResponse> {
    const response = await fetch('/api/customers', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...AuthService.getAuthHeader(),
      },
      body: JSON.stringify(request),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to create customer');
    }
    return response.json();
  }

  static async updateCustomer(customerId: number, request: UpdateCustomerRequest): Promise<CustomerResponse> {
    const response = await fetch(`/api/customers/${customerId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        ...AuthService.getAuthHeader(),
      },
      body: JSON.stringify(request),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to update customer');
    }
    return response.json();
  }

  static async deleteCustomer(customerId: number): Promise<StatusResponse> {
    const response = await fetch(`/api/customers/${customerId}`, {
      method: 'DELETE',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to delete customer');
    }
    return response.json();
  }
}
