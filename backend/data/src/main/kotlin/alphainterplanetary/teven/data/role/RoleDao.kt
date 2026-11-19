package alphainterplanetary.teven.data.role

import alphainterplanetary.teven.api.model.role.CreateRoleRequest
import alphainterplanetary.teven.api.model.role.RoleResponse
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.data.dbQuery
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.jetbrains.exposed.v1.core.ResultRow
import org.jetbrains.exposed.v1.core.and
import org.jetbrains.exposed.v1.core.eq
import org.jetbrains.exposed.v1.jdbc.deleteWhere
import org.jetbrains.exposed.v1.jdbc.insert
import org.jetbrains.exposed.v1.jdbc.select
import org.jetbrains.exposed.v1.jdbc.selectAll

class RoleDao {
  private val json = Json

  private fun parsePermissions(raw: String): List<String> {
    val names: List<String> = if (raw.trimStart().startsWith("[")) {
      runCatching { json.decodeFromString<List<String>>(raw) }.getOrDefault(emptyList())
    } else {
      raw.split(",").map { it.trim() }.filter { it.isNotEmpty() }
    }
    return names.map { Permission.valueOf(it).name }
  }

  private fun encodePermissions(permissions: List<String>): String =
    json.encodeToString(permissions.map { Permission.valueOf(it).name })

  private fun toRoleResponse(row: ResultRow): RoleResponse {
    return RoleResponse(
      roleId = row[Roles.id].value,
      roleName = row[Roles.roleName],
      permissions = parsePermissions(row[Roles.permissions]),
    )
  }

  suspend fun createRole(createRoleRequest: CreateRoleRequest): RoleResponse = dbQuery {
    val id = Roles.insert {
      it[roleName] = createRoleRequest.roleName
      it[permissions] = encodePermissions(createRoleRequest.permissions)
    } get Roles.id

    RoleResponse(
      roleId = id.value,
      roleName = createRoleRequest.roleName,
      permissions = createRoleRequest.permissions.map { Permission.valueOf(it).name },
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

  // Role definitions are seed-managed; runtime update/delete endpoints are removed.

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
