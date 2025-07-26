
package com.teven.service.role

import com.teven.api.model.role.CreateRoleRequest
import com.teven.api.model.role.RoleResponse
import com.teven.api.model.role.UpdateRoleRequest
import com.teven.data.role.RoleDao

class RoleService(private val roleDao: RoleDao) {
    fun createRole(createRoleRequest: CreateRoleRequest): RoleResponse {
        return roleDao.createRole(createRoleRequest)
    }

    fun getAllRoles(): List<RoleResponse> {
        return roleDao.getAllRoles()
    }

    fun getRoleById(roleId: Int): RoleResponse? {
        return roleDao.getRoleById(roleId)
    }

    fun getRoleByName(roleName: String): RoleResponse? {
        return roleDao.getRoleByName(roleName)
    }

    fun updateRole(roleId: Int, updateRoleRequest: UpdateRoleRequest): Boolean {
        return roleDao.updateRole(roleId, updateRoleRequest)
    }

    fun deleteRole(roleId: Int): Boolean {
        return roleDao.deleteRole(roleId)
    }

    fun assignRoleToUser(userId: Int, roleId: Int): Boolean {
        return roleDao.assignRoleToUser(userId, roleId)
    }

    fun removeRoleFromUser(userId: Int, roleId: Int): Boolean {
        return roleDao.removeRoleFromUser(userId, roleId)
    }
}
