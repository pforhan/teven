import type { RoleResponse } from '../types/roles';
import { apiClient } from './apiClient';

export class RoleService {
  static async getAllRoles(): Promise<RoleResponse[]> {
    return apiClient('/api/roles');
  }
}