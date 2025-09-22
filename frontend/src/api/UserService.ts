import type { UserResponse, CreateUserRequest, UpdateUserRequest } from '../types/auth';
import { apiClient } from './apiClient';

export class UserService {
  static async getAllUsers(organizationId?: number): Promise<UserResponse[]> {
    const url = new URL('/api/users', window.location.origin);
    if (organizationId) {
      url.searchParams.append('organizationId', organizationId.toString());
    }
    return apiClient<UserResponse[]>(url.toString());
  }

  static async getUser(userId: number): Promise<UserResponse> {
    return apiClient<UserResponse>(`/api/users/${userId}`);
  }

  static async createUser(request: CreateUserRequest): Promise<UserResponse> {
    return apiClient<UserResponse>('/api/users', {
      method: 'POST',
      body: JSON.stringify(request),
    });
  }

  static async updateUser(userId: number, request: UpdateUserRequest): Promise<UserResponse> {
    return apiClient<UserResponse>(`/api/users/${userId}`, {
      method: 'PUT',
      body: JSON.stringify(request),
    });
  }

  static async deleteUser(userId: number): Promise<void> {
    return apiClient<void>(`/api/users/${userId}`, {
      method: 'DELETE',
    });
  }
}
