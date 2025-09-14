package alphainterplanetary.teven.core.service

import alphainterplanetary.teven.api.model.role.CreateRoleRequest
import alphainterplanetary.teven.api.model.role.RoleResponse
import alphainterplanetary.teven.api.model.role.UpdateRoleRequest

interface RoleService {
  suspend fun createRole(createRoleRequest: CreateRoleRequest): RoleResponse
  suspend fun getAllRoles(): List<RoleResponse>
  suspend fun getRoleById(roleId: Int): RoleResponse?
  suspend fun getRoleByName(roleName: String): RoleResponse?
  suspend fun updateRole(roleId: Int, updateRoleRequest: UpdateRoleRequest): Boolean
  suspend fun deleteRole(roleId: Int): Boolean
  suspend fun assignRoleToUser(userId: Int, roleId: Int): Boolean
  suspend fun removeRoleFromUser(userId: Int, roleId: Int): Boolean
  suspend fun getRolesForUser(userId: Int): List<RoleResponse>
}