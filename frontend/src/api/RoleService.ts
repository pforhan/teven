// frontend/src/api/RoleService.ts

import type { CreateRoleRequest, RoleResponse, UpdateRoleRequest } from '../types/roles';
import type { StatusResponse } from '../types/common';
import { AuthService } from './AuthService';

export class RoleService {
  static async createRole(request: CreateRoleRequest): Promise<RoleResponse> {
    const response = await fetch('/api/roles', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...AuthService.getAuthHeader(),
      },
      body: JSON.stringify(request),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to create role');
    }
    return response.json();
  }

  static async getAllRoles(): Promise<RoleResponse[]> {
    const response = await fetch('/api/roles', {
      method: 'GET',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to fetch roles');
    }
    return response.json();
  }

  static async getRole(roleId: number): Promise<RoleResponse> {
    const response = await fetch(`/api/roles/${roleId}`, {
      method: 'GET',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to fetch role');
    }
    return response.json();
  }

  static async updateRole(roleId: number, request: UpdateRoleRequest): Promise<RoleResponse> {
    const response = await fetch(`/api/roles/${roleId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        ...AuthService.getAuthHeader(),
      },
      body: JSON.stringify(request),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to update role');
    }
    return response.json();
  }

  static async deleteRole(roleId: number): Promise<StatusResponse> {
    const response = await fetch(`/api/roles/${roleId}`, {
      method: 'DELETE',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to delete role');
    }
    return response.json();
  }

  static async assignRoleToUser(userId: number, roleId: number): Promise<StatusResponse> {
    const response = await fetch(`/api/users/${userId}/roles/${roleId}`, {
      method: 'POST',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to assign role to user');
    }
    return response.json();
  }

  static async removeRoleFromUser(userId: number, roleId: number): Promise<StatusResponse> {
    const response = await fetch(`/api/users/${userId}/roles/${roleId}`, {
      method: 'DELETE',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to remove role from user');
    }
    return response.json();
  }
}
