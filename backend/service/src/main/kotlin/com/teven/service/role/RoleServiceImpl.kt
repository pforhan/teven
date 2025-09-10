package com.teven.service.role

import com.teven.api.model.role.CreateRoleRequest
import com.teven.api.model.role.RoleResponse
import com.teven.api.model.role.UpdateRoleRequest
import com.teven.core.service.RoleService
import com.teven.data.role.RoleDao

class RoleServiceImpl(
  private val roleDao: RoleDao,
) : RoleService {
  override suspend fun createRole(createRoleRequest: CreateRoleRequest): RoleResponse {
    return roleDao.createRole(createRoleRequest)
  }

  override suspend fun getAllRoles(): List<RoleResponse> {
    return roleDao.getAllRoles()
  }

  override suspend fun getRoleById(roleId: Int): RoleResponse? {
    return roleDao.getRoleById(roleId)
  }

  override suspend fun getRoleByName(roleName: String): RoleResponse? {
    return roleDao.getRoleByName(roleName)
  }

  override suspend fun updateRole(roleId: Int, updateRoleRequest: UpdateRoleRequest): Boolean {
    return roleDao.updateRole(roleId, updateRoleRequest)
  }

  override suspend fun deleteRole(roleId: Int): Boolean {
    return roleDao.deleteRole(roleId)
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
