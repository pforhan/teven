package alphainterplanetary.teven.data.role

import alphainterplanetary.teven.api.model.role.CreateRoleRequest
import alphainterplanetary.teven.api.model.role.RoleResponse
import alphainterplanetary.teven.api.model.role.UpdateRoleRequest
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.data.dbQuery
import org.jetbrains.exposed.v1.core.ResultRow
import org.jetbrains.exposed.v1.core.and
import org.jetbrains.exposed.v1.core.eq
import org.jetbrains.exposed.v1.jdbc.deleteWhere
import org.jetbrains.exposed.v1.jdbc.insert
import org.jetbrains.exposed.v1.jdbc.select
import org.jetbrains.exposed.v1.jdbc.selectAll
import org.jetbrains.exposed.v1.jdbc.update

class RoleDao {
  private fun toRoleResponse(row: ResultRow): RoleResponse {
    return RoleResponse(
      roleId = row[Roles.id].value,
      roleName = row[Roles.roleName],
      permissions = row[Roles.permissions].split(",").map { it.trim() }
        .map { Permission.valueOf(it).name }
    )
  }

  suspend fun createRole(createRoleRequest: CreateRoleRequest): RoleResponse = dbQuery {
    val id = Roles.insert {
      it[roleName] = createRoleRequest.roleName
      it[permissions] = createRoleRequest.permissions.joinToString(",") { permission ->
        Permission.valueOf(permission).name
      }
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
    Roles.selectAll()
      .where { Roles.id eq roleId }
      .mapNotNull { toRoleResponse(it) }
      .singleOrNull()
  }

  suspend fun getRoleByName(roleName: String): RoleResponse? = dbQuery {
    Roles.selectAll()
      .where { Roles.roleName eq roleName }
      .mapNotNull { toRoleResponse(it) }
      .singleOrNull()
  }

  suspend fun updateRole(roleId: Int, updateRoleRequest: UpdateRoleRequest): Boolean = dbQuery {
    Roles.update({ Roles.id eq roleId }) {
      updateRoleRequest.roleName?.let { roleName -> it[Roles.roleName] = roleName }
      updateRoleRequest.permissions?.let { permissions ->
        it[Roles.permissions] =
          permissions.joinToString(",") { permission -> Permission.valueOf(permission).name }
      }
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

  suspend fun getRolesForUser(userId: Int): List<RoleResponse> = dbQuery {
    (UserRoles innerJoin Roles)
      .select(Roles.columns)
      .where { UserRoles.userId eq userId }
      .map { toRoleResponse(it) }
  }
}
