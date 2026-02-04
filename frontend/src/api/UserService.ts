import type { UserResponse, CreateUserRequest, UpdateUserRequest } from '../types/auth';
import type { PaginatedResponse } from '../types/common';
import { apiClient } from './apiClient';

export class UserService {
  static async getAllUsers(
    limit?: number,
    offset?: number,
    search?: string,
    sortBy?: string,
    sortOrder?: 'asc' | 'desc',
    organizationId?: number
  ): Promise<PaginatedResponse<UserResponse>> {
    const url = new URL('/api/users', window.location.origin);
    if (limit !== undefined) url.searchParams.append('limit', limit.toString());
    if (offset !== undefined) url.searchParams.append('offset', offset.toString());
    if (search) url.searchParams.append('search', search);
    if (sortBy) url.searchParams.append('sortBy', sortBy);
    if (sortOrder) url.searchParams.append('sortOrder', sortOrder);
    if (organizationId) url.searchParams.append('organizationId', organizationId.toString());

    return apiClient<PaginatedResponse<UserResponse>>(url.toString());
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
