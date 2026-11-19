package alphainterplanetary.teven.core.service

import alphainterplanetary.teven.api.model.role.RoleResponse

interface RoleService {
  suspend fun getAllRoles(): List<RoleResponse>
  suspend fun getRoleById(roleId: Int): RoleResponse?
  suspend fun getRoleByName(roleName: String): RoleResponse?
  suspend fun assignRoleToUser(userId: Int, roleId: Int): Boolean
  suspend fun removeRoleFromUser(userId: Int, roleId: Int): Boolean
  suspend fun getRolesForUser(userId: Int): List<RoleResponse>
}