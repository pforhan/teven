
package com.teven.data.role

import com.teven.api.model.role.CreateRoleRequest
import com.teven.api.model.role.RoleResponse
import com.teven.api.model.role.UpdateRoleRequest
import com.teven.data.dbQuery
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
import org.jetbrains.exposed.sql.and
import org.jetbrains.exposed.sql.deleteWhere
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.select
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.update

class RoleDao {
    private fun toRoleResponse(row: ResultRow): RoleResponse {
        return RoleResponse(
            roleId = row[Roles.id].value,
            roleName = row[Roles.roleName],
            permissions = row[Roles.permissions].split(",")
        )
    }

    suspend fun createRole(createRoleRequest: CreateRoleRequest): RoleResponse = dbQuery {
        val id = Roles.insert {
            it[roleName] = createRoleRequest.roleName
            it[permissions] = createRoleRequest.permissions.joinToString(",")
        } get Roles.id

        RoleResponse(
            roleId = id.value,
            roleName = createRoleRequest.roleName,
            permissions = createRoleRequest.permissions
        )
    }

    suspend fun getAllRoles(): List<RoleResponse> = dbQuery {
        Roles.selectAll().map { toRoleResponse(it) }
    }

    suspend fun getRoleById(roleId: Int): RoleResponse? = dbQuery {
        Roles.select { Roles.id eq roleId }
            .mapNotNull { toRoleResponse(it) }
            .singleOrNull()
    }

    suspend fun getRoleByName(roleName: String): RoleResponse? = dbQuery {
        Roles.select { Roles.roleName eq roleName }
            .mapNotNull { toRoleResponse(it) }
            .singleOrNull()
    }

    suspend fun updateRole(roleId: Int, updateRoleRequest: UpdateRoleRequest): Boolean = dbQuery {
        Roles.update({ Roles.id eq roleId }) {
            updateRoleRequest.roleName?.let { roleName -> it[Roles.roleName] = roleName }
            updateRoleRequest.permissions?.let { permissions -> it[Roles.permissions] = permissions.joinToString(",") }
        } > 0
    }

    suspend fun deleteRole(roleId: Int): Boolean = dbQuery {
        Roles.deleteWhere { Roles.id eq roleId } > 0
    }

    suspend fun assignRoleToUser(userId: Int, roleId: Int): Boolean = dbQuery {
        val insertStatement = UserRoles.insert {
            it[UserRoles.userId] = userId
            it[UserRoles.roleId] = roleId
        }
        insertStatement.resultedValues?.isNotEmpty() ?: false
    }

    suspend fun removeRoleFromUser(userId: Int, roleId: Int): Boolean = dbQuery {
        UserRoles.deleteWhere { (UserRoles.userId eq userId) and (UserRoles.roleId eq roleId) } > 0
    }
}
