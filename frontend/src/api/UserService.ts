import type { UserResponse } from '../types/auth';
import { apiClient } from './apiClient';

export class UserService {
  static async getAllUsers(): Promise<UserResponse[]> {
    return apiClient('/api/users');
  }
}
