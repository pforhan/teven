import type { LoginRequest, LoginResponse, UserResponse, UserDetailsResponse, UpdateUserRequest, UserContextResponse } from '../types/auth';
import { apiClient } from './apiClient';

export const TOKEN_KEY = 'teven-auth-token';

export class AuthService {

  static async login(request: LoginRequest): Promise<LoginResponse> {
    const data = await apiClient<LoginResponse>('/api/users/login', {
      method: 'POST',
      body: JSON.stringify(request),
    });
    if (data.token) {
      localStorage.setItem(TOKEN_KEY, data.token);
    }
    return data;
  }

  static logout() {
    localStorage.removeItem(TOKEN_KEY);
  }

  static getToken(): string | null {
    return localStorage.getItem(TOKEN_KEY);
  }

  static getAuthHeader(): { [key: string]: string } {
    const token = this.getToken();
    if (token) {
      return { 'Authorization': `Bearer ${token}` };
    }
    return {};
  }

  static async getUserDetails(userId: number): Promise<UserDetailsResponse> {
    return apiClient<UserDetailsResponse>(`/api/users/${userId}`);
  }

  static async updateUserDetails(userId: number, request: UpdateUserRequest): Promise<UserResponse> {
    return apiClient<UserResponse>(`/api/users/${userId}`, {
      method: 'PUT',
      body: JSON.stringify(request),
    });
  }

  static async getUserContext(): Promise<UserContextResponse> {
    return apiClient<UserContextResponse>('/api/users/context');
  }
}
