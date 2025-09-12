import type { OrganizationResponse, CreateOrganizationRequest, UpdateOrganizationRequest } from '../types/organizations';
import type { StatusResponse } from '../types/common';
import { apiClient } from './apiClient';

export class OrganizationService {
  static async getAllOrganizations(): Promise<OrganizationResponse[]> {
    return apiClient<OrganizationResponse[]>('/api/organizations');
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