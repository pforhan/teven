import type { CustomerResponse, CreateCustomerRequest, UpdateCustomerRequest } from '../types/customers';
import type { StatusResponse, PaginatedResponse } from '../types/common';
import { apiClient } from './apiClient';

export class CustomerService {
  static async getAllCustomers(
    limit?: number,
    offset?: number,
    search?: string,
    sortBy?: string,
    sortOrder?: 'asc' | 'desc',
    organizationId?: number
  ): Promise<PaginatedResponse<CustomerResponse>> {
    const url = new URL('/api/customers', window.location.origin);
    if (limit !== undefined) url.searchParams.append('limit', limit.toString());
    if (offset !== undefined) url.searchParams.append('offset', offset.toString());
    if (search) url.searchParams.append('search', search);
    if (sortBy) url.searchParams.append('sortBy', sortBy);
    if (sortOrder) url.searchParams.append('sortOrder', sortOrder);
    if (organizationId) url.searchParams.append('organizationId', organizationId.toString());

    return apiClient<PaginatedResponse<CustomerResponse>>(url.toString());
  }

  static async getCustomer(customerId: number): Promise<CustomerResponse> {
    return apiClient<CustomerResponse>(`/api/customers/${customerId}`);
  }

  static async createCustomer(request: CreateCustomerRequest): Promise<CustomerResponse> {
    return apiClient<CustomerResponse>('/api/customers', {
      method: 'POST',
      body: JSON.stringify(request),
    });
  }

  static async updateCustomer(customerId: number, request: UpdateCustomerRequest): Promise<CustomerResponse> {
    return apiClient<CustomerResponse>(`/api/customers/${customerId}`, {
      method: 'PUT',
      body: JSON.stringify(request),
    });
  }

  static async deleteCustomer(customerId: number): Promise<StatusResponse> {
    return apiClient<StatusResponse>(`/api/customers/${customerId}`, { method: 'DELETE' });
  }
}
