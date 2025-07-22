
package com.teven.data.role

import com.teven.api.model.role.CreateRoleRequest
import com.teven.api.model.role.RoleResponse
import com.teven.api.model.role.UpdateRoleRequest
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
import org.jetbrains.exposed.sql.and
import org.jetbrains.exposed.sql.deleteWhere
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.select
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.transactions.transaction
import org.jetbrains.exposed.sql.update

class RoleDao {
    private fun toRoleResponse(row: ResultRow): RoleResponse {
        return RoleResponse(
            roleId = row[Roles.id].value,
            roleName = row[Roles.roleName],
            permissions = row[Roles.permissions].split(",")
        )
    }

    fun createRole(createRoleRequest: CreateRoleRequest): RoleResponse {
        return transaction {
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
    }

    fun getAllRoles(): List<RoleResponse> {
        return transaction {
            Roles.selectAll().map { toRoleResponse(it) }
        }
    }

    fun getRoleById(roleId: Int): RoleResponse? {
        return transaction {
            Roles.select { Roles.id eq roleId }
                .mapNotNull { toRoleResponse(it) }
                .singleOrNull()
        }
    }

    fun updateRole(roleId: Int, updateRoleRequest: UpdateRoleRequest): Boolean {
        return transaction {
            Roles.update({ Roles.id eq roleId }) {
                updateRoleRequest.roleName?.let { roleName -> it[Roles.roleName] = roleName }
                updateRoleRequest.permissions?.let { permissions -> it[Roles.permissions] = permissions.joinToString(",") }
            } > 0
        }
    }

    fun deleteRole(roleId: Int): Boolean {
        return transaction {
            Roles.deleteWhere { Roles.id eq roleId } > 0
        }
    }

    fun assignRoleToUser(userId: Int, roleId: Int): Boolean {
        return transaction {
            val insertStatement = UserRoles.insert {
                it[UserRoles.userId] = userId
                it[UserRoles.roleId] = roleId
            }
            insertStatement.resultedValues?.isNotEmpty() ?: false
        }
    }

    fun removeRoleFromUser(userId: Int, roleId: Int): Boolean {
        return transaction {
            UserRoles.deleteWhere { (UserRoles.userId eq userId) and (UserRoles.roleId eq roleId) } > 0        }
    }
}
