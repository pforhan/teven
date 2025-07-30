// frontend/src/api/AuthService.ts

import type { LoginRequest, LoginResponse, RegisterRequest, UserResponse, UserDetailsResponse, UpdateUserRequest, UserContextResponse } from '../types/auth';

export const TOKEN_KEY = 'teven-auth-token';

export class AuthService {
  static async register(request: RegisterRequest): Promise<UserResponse> {
    const response = await fetch('/api/users/register', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(request),
    });
    if (!response.ok) {
      throw new Error('Registration failed');
    }
    return response.json();
  }

  static async login(request: LoginRequest): Promise<LoginResponse> {
    const response = await fetch('/api/users/login', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(request),
    });
    if (!response.ok) {
      throw new Error('Login failed');
    }
    const data = await response.json();
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
    const response = await fetch(`/api/users/${userId}`, {
      headers: this.getAuthHeader(),
    });
    if (!response.ok) {
      throw new Error('Failed to get user details');
    }
    return response.json();
  }

  static async updateUserDetails(userId: number, request: UpdateUserRequest): Promise<UserResponse> {
    const response = await fetch(`/api/users/${userId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        ...this.getAuthHeader(),
      },
      body: JSON.stringify(request),
    });
    if (!response.ok) {
      throw new Error('Failed to update user details');
    }
    return response.json();
  }

  static async getUserContext(): Promise<UserContextResponse> {
    try {
      const response = await fetch('/api/users/context', {
        headers: this.getAuthHeader(),
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error('AuthService: Failed to get user context. Server response:', errorText);
        throw new Error(`Failed to get user context: ${response.status} ${response.statusText}`);
      }

      return await response.json();
    } catch (err) {
      if (err instanceof Error) {
        console.error('AuthService: Error in getUserContext:', err.message);
        throw err;
      } else {
        console.error('AuthService: An unknown error occurred in getUserContext');
        throw new Error('An unknown error occurred');
      }
    }
  }
}
