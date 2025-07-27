// frontend/src/api/AuthService.ts

import { LoginRequest, LoginResponse, RegisterRequest, UserResponse, UserDetailsResponse, UpdateUserRequest, UserContextResponse } from '../types/auth';
import { StatusResponse } from '../types/common';

export class AuthService {
  // TODO: Implement register user
  static async register(request: RegisterRequest): Promise<UserResponse> {
    console.log('Registering user:', request);
    throw new Error('Not implemented');
  }

  // TODO: Implement login user
  static async login(request: LoginRequest): Promise<LoginResponse> {
    console.log('Logging in user:', request);
    throw new Error('Not implemented');
  }

  // TODO: Implement get user details
  static async getUserDetails(userId: number): Promise<UserDetailsResponse> {
    console.log('Getting user details for:', userId);
    throw new Error('Not implemented');
  }

  // TODO: Implement update user details
  static async updateUserDetails(userId: number, request: UpdateUserRequest): Promise<UserResponse> {
    console.log('Updating user details for:', userId, request);
    throw new Error('Not implemented');
  }

  // TODO: Implement get user context
  static async getUserContext(): Promise<UserContextResponse> {
    console.log('Getting user context');
    throw new Error('Not implemented');
  }
}
