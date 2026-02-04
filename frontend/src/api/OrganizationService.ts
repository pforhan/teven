import type { OrganizationResponse, CreateOrganizationRequest, UpdateOrganizationRequest } from '../types/organizations';
import type { StatusResponse, PaginatedResponse } from '../types/common';
import { apiClient } from './apiClient';

export class OrganizationService {
  static async getAllOrganizations(
    limit?: number,
    offset?: number,
    search?: string,
    sortBy?: string,
    sortOrder?: 'asc' | 'desc'
  ): Promise<PaginatedResponse<OrganizationResponse>> {
    const url = new URL('/api/organizations', window.location.origin);
    if (limit !== undefined) url.searchParams.append('limit', limit.toString());
    if (offset !== undefined) url.searchParams.append('offset', offset.toString());
    if (search) url.searchParams.append('search', search);
    if (sortBy) url.searchParams.append('sortBy', sortBy);
    if (sortOrder) url.searchParams.append('sortOrder', sortOrder);

    return apiClient<PaginatedResponse<OrganizationResponse>>(url.toString());
  }

  static async getOrganization(organizationId: number): Promise<OrganizationResponse> {
    return apiClient<OrganizationResponse>(`/api/organizations/${organizationId}`);
  }

  static async createOrganization(request: CreateOrganizationRequest): Promise<OrganizationResponse> {
    return apiClient<OrganizationResponse>('/api/organizations', {
      method: 'POST',
      body: JSON.stringify(request),
    });
  }

  static async updateOrganization(organizationId: number, request: UpdateOrganizationRequest): Promise<OrganizationResponse> {
    return apiClient<OrganizationResponse>(`/api/organizations/${organizationId}`, {
      method: 'PUT',
      body: JSON.stringify(request),
    });
  }

  static async deleteOrganization(organizationId: number): Promise<StatusResponse> {
    return apiClient<StatusResponse>(`/api/organizations/${organizationId}`, { method: 'DELETE' });
  }
}