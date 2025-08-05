import type { CreateRoleRequest, RoleResponse, UpdateRoleRequest } from '../types/roles';
import type { StatusResponse } from '../types/common';
import { apiClient } from './apiClient';

export class RoleService {
  static async createRole(request: CreateRoleRequest): Promise<RoleResponse> {
    return apiClient('/api/roles', {
      method: 'POST',
      body: JSON.stringify(request),
    });
  }

  static async getAllRoles(): Promise<RoleResponse[]> {
    return apiClient('/api/roles');
  }

  static async getRole(roleId: number): Promise<RoleResponse> {
    return apiClient(`/api/roles/${roleId}`);
  }

  static async updateRole(roleId: number, request: UpdateRoleRequest): Promise<RoleResponse> {
    return apiClient(`/api/roles/${roleId}`, {
      method: 'PUT',
      body: JSON.stringify(request),
    });
  }

  static async deleteRole(roleId: number): Promise<StatusResponse> {
    return apiClient(`/api/roles/${roleId}`, { method: 'DELETE' });
  }

  static async assignRoleToUser(userId: number, roleId: number): Promise<StatusResponse> {
    return apiClient(`/api/users/${userId}/roles/${roleId}`, { method: 'POST' });
  }

  static async removeRoleFromUser(userId: number, roleId: number): Promise<StatusResponse> {
    return apiClient(`/api/users/${userId}/roles/${roleId}`, { method: 'DELETE' });
  }
}
