// frontend/src/api/CustomerService.ts

import type { CustomerResponse, CreateCustomerRequest, UpdateCustomerRequest } from '../types/customers';
import type { StatusResponse } from '../types/common';

export class CustomerService {
  private static getAuthHeaders(): HeadersInit {
    const token = localStorage.getItem('authToken');
    if (!token) {
      throw new Error('Authentication token not found');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    };
  }

  static async getAllCustomers(): Promise<CustomerResponse[]> {
    const response = await fetch('/api/customers', {
      method: 'GET',
      headers: CustomerService.getAuthHeaders(),
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
      headers: CustomerService.getAuthHeaders(),
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
      headers: CustomerService.getAuthHeaders(),
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
      headers: CustomerService.getAuthHeaders(),
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
      headers: CustomerService.getAuthHeaders(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to delete customer');
    }
    return response.json();
  }
}
