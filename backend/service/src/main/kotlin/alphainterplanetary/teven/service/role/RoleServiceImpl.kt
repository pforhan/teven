package alphainterplanetary.teven.service.role

import alphainterplanetary.teven.api.model.role.RoleResponse
import alphainterplanetary.teven.core.service.RoleService
import alphainterplanetary.teven.data.role.RoleDao

class RoleServiceImpl(
  private val roleDao: RoleDao,
) : RoleService {
  override suspend fun getAllRoles(): List<RoleResponse> {
    return roleDao.getAllRoles()
  }

  override suspend fun getRoleById(roleId: Int): RoleResponse? {
    return roleDao.getRoleById(roleId)
  }

  override suspend fun getRoleByName(roleName: String): RoleResponse? {
    return roleDao.getRoleByName(roleName)
  }

  override suspend fun assignRoleToUser(userId: Int, roleId: Int): Boolean {
    return roleDao.assignRoleToUser(userId, roleId)
  }

  override suspend fun removeRoleFromUser(userId: Int, roleId: Int): Boolean {
    return roleDao.removeRoleFromUser(userId, roleId)
  }

  override suspend fun getRolesForUser(userId: Int): List<RoleResponse> {
    return roleDao.getRolesForUser(userId)
  }
}
