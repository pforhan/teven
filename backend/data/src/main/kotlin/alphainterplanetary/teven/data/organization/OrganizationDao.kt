package alphainterplanetary.teven.data.organization

import alphainterplanetary.teven.api.model.common.PaginatedResponse
import alphainterplanetary.teven.api.model.organization.CreateOrganizationRequest
import alphainterplanetary.teven.api.model.organization.OrganizationResponse
import alphainterplanetary.teven.api.model.organization.UpdateOrganizationRequest
import alphainterplanetary.teven.data.dbQuery
import alphainterplanetary.teven.data.user.UserOrganizations
import org.jetbrains.exposed.v1.core.Op
import org.jetbrains.exposed.v1.core.ResultRow
import org.jetbrains.exposed.v1.core.SortOrder
import org.jetbrains.exposed.v1.core.and
import org.jetbrains.exposed.v1.core.eq
import org.jetbrains.exposed.v1.core.like
import org.jetbrains.exposed.v1.core.lowerCase
import org.jetbrains.exposed.v1.jdbc.deleteWhere
import org.jetbrains.exposed.v1.jdbc.insert
import org.jetbrains.exposed.v1.jdbc.selectAll
import org.jetbrains.exposed.v1.jdbc.update

class OrganizationDao {

  suspend fun createOrganization(request: CreateOrganizationRequest): OrganizationResponse =
    dbQuery {
      val insertStatement = Organizations.insert {
        it[name] = request.name
        it[contactInformation] = request.contactInformation
      }
      insertStatement.resultedValues?.firstOrNull()?.let { toOrganizationResponse(it) }
        ?: throw Exception("Failed to create organization")
    }

  suspend fun getOrganizations(
    search: String?,
    limit: Int?,
    offset: Long?,
    sortBy: String?,
    sortOrder: String?,
  ): PaginatedResponse<OrganizationResponse> = dbQuery {
    val conditions = mutableListOf<Op<Boolean>>()
    search?.let { conditions.add(Organizations.name.lowerCase() like "%${it.lowercase()}%") }

    val query = if (conditions.isEmpty()) {
      Organizations.selectAll()
    } else {
      val combinedCondition = conditions.reduce { acc, op -> acc and op }
      Organizations.selectAll().where { combinedCondition }
    }

    val total = query.count()

    val sort = if (sortOrder == "desc") SortOrder.DESC else SortOrder.ASC
    when (sortBy) {
      "name" -> query.orderBy(Organizations.name, sort)
      else -> query.orderBy(Organizations.id, sort)
    }

    offset?.let { query.offset(it) }
    limit?.let { query.limit(it) }

    val organizations = query.map { toOrganizationResponse(it) }

    PaginatedResponse(
      items = organizations,
      total = total,
      offset = offset ?: 0,
      limit = limit ?: 0,
    )
  }

  suspend fun getAllOrganizations(): List<OrganizationResponse> = dbQuery {
    Organizations.selectAll().map { toOrganizationResponse(it) }
  }

  suspend fun getOrganizationById(organizationId: Int): OrganizationResponse? = dbQuery {
    Organizations.selectAll()
      .where { Organizations.id eq organizationId }
      .map { toOrganizationResponse(it) }
      .singleOrNull()
  }

  suspend fun updateOrganization(organizationId: Int, request: UpdateOrganizationRequest): Boolean =
    dbQuery {
      Organizations.update({ Organizations.id eq organizationId }) {
        request.name?.let { name -> it[Organizations.name] = name }
        request.contactInformation?.let { contactInformation ->
          it[Organizations.contactInformation] = contactInformation
        }
      } > 0
    }

  suspend fun deleteOrganization(organizationId: Int): Boolean = dbQuery {
    Organizations.deleteWhere { Organizations.id eq organizationId } > 0
  }

  suspend fun assignUserToOrganization(userId: Int, organizationId: Int): Boolean = dbQuery {
    UserOrganizations.insert {
      it[UserOrganizations.userId] = userId
      it[UserOrganizations.organizationId] = organizationId
    }.insertedCount > 0
  }

  private fun toOrganizationResponse(row: ResultRow): OrganizationResponse {
    return OrganizationResponse(
      organizationId = row[Organizations.id].value,
      name = row[Organizations.name],
      contactInformation = row[Organizations.contactInformation]
    )
  }
}
