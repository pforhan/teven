import type { LoginRequest, LoginResponse, RegisterRequest, UserResponse, UserDetailsResponse, UpdateUserRequest, UserContextResponse } from '../types/auth';
import { apiClient } from './apiClient';

export const TOKEN_KEY = 'teven-auth-token';

export class AuthService {
  static async register(request: RegisterRequest): Promise<UserResponse> {
    return apiClient('/api/users/register', {
      method: 'POST',
      body: JSON.stringify(request),
    });
  }

  static async login(request: LoginRequest): Promise<LoginResponse> {
    const data = await apiClient('/api/users/login', {
      method: 'POST',
      body: JSON.stringify(request),
    });
    if (data.token) {
      console.log('AuthService: Setting token in localStorage.');
      localStorage.setItem(TOKEN_KEY, data.token);
    }
    return data;
  }

  static logout() {
    console.log('AuthService: Removing token from localStorage.');
    localStorage.removeItem(TOKEN_KEY);
  }

  static getToken(): string | null {
    const token = localStorage.getItem(TOKEN_KEY);
    console.log('AuthService: Getting token from localStorage. Token present:', !!token);
    return token;
  }

  static getAuthHeader(): { [key: string]: string } {
    const token = this.getToken();
    if (token) {
      return { 'Authorization': `Bearer ${token}` };
    }
    return {};
  }

  static async getUserDetails(userId: number): Promise<UserDetailsResponse> {
    return apiClient(`/api/users/${userId}`);
  }

  static async updateUserDetails(userId: number, request: UpdateUserRequest): Promise<UserResponse> {
    return apiClient(`/api/users/${userId}`, {
      method: 'PUT',
      body: JSON.stringify(request),
    });
  }

  static async getUserContext(): Promise<UserContextResponse> {
    return apiClient('/api/users/context');
  }
}
