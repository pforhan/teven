// frontend/src/api/OrganizationService.ts

import type { OrganizationResponse, CreateOrganizationRequest, UpdateOrganizationRequest } from '../types/organizations';
import type { StatusResponse } from '../types/common';
import { AuthService } from './AuthService';

export class OrganizationService {
  static async getAllOrganizations(): Promise<OrganizationResponse[]> {
    const response = await fetch('/api/organizations', {
      method: 'GET',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to fetch organizations');
    }
    return response.json();
  }

  static async getOrganizationById(organizationId: number): Promise<OrganizationResponse> {
    const response = await fetch(`/api/organizations/${organizationId}`, {
      method: 'GET',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to fetch organization');
    }
    return response.json();
  }

  static async createOrganization(request: CreateOrganizationRequest): Promise<OrganizationResponse> {
    const response = await fetch('/api/organizations', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...AuthService.getAuthHeader(),
      },
      body: JSON.stringify(request),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to create organization');
    }
    return response.json();
  }

  static async updateOrganization(organizationId: number, request: UpdateOrganizationRequest): Promise<OrganizationResponse> {
    const response = await fetch(`/api/organizations/${organizationId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        ...AuthService.getAuthHeader(),
      },
      body: JSON.stringify(request),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to update organization');
    }
    return response.json();
  }

  static async deleteOrganization(organizationId: number): Promise<StatusResponse> {
    const response = await fetch(`/api/organizations/${organizationId}`, {
      method: 'DELETE',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to delete organization');
    }
    return response.json();
  }
}
