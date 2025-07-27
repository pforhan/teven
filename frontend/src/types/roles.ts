// frontend/src/types/roles.ts

export interface CreateRoleRequest {
  roleName: string;
  permissions: string[];
}

export interface RoleResponse {
  roleId: number;
  roleName: string;
  permissions: string[];
}

export interface UpdateRoleRequest {
  roleName?: string;
  permissions?: string[];
}
