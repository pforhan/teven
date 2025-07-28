package com.teven.data.organization

import com.teven.api.model.organization.CreateOrganizationRequest
import com.teven.api.model.organization.OrganizationResponse
import com.teven.api.model.organization.UpdateOrganizationRequest
import com.teven.data.dbQuery
import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
import org.jetbrains.exposed.sql.transactions.transaction

object Organizations : Table() {
    val organizationId = integer("organization_id").autoIncrement()
    val name = varchar("name", 255).uniqueIndex()
    val contactInformation = varchar("contact_information", 255)

    override val primaryKey = PrimaryKey(organizationId)
}

class OrganizationDao {
    init {
        transaction {
            SchemaUtils.create(Organizations)
        }
    }

    suspend fun createOrganization(request: CreateOrganizationRequest): OrganizationResponse = dbQuery {
        val insertStatement = Organizations.insert {
            it[name] = request.name
            it[contactInformation] = request.contactInformation
        }
        insertStatement.resultedValues?.firstOrNull()?.let { toOrganizationResponse(it) }
            ?: throw Exception("Failed to create organization")
    }

    suspend fun getAllOrganizations(): List<OrganizationResponse> = dbQuery {
        Organizations.selectAll().map { toOrganizationResponse(it) }
    }

    suspend fun getOrganizationById(organizationId: Int): OrganizationResponse? = dbQuery {
        Organizations.select { Organizations.organizationId eq organizationId }
            .map { toOrganizationResponse(it) }
            .singleOrNull()
    }

    suspend fun updateOrganization(organizationId: Int, request: UpdateOrganizationRequest): Boolean = dbQuery {
        Organizations.update({ Organizations.organizationId eq organizationId }) {
            request.name?.let { name -> it[Organizations.name] = name }
            request.contactInformation?.let { contactInformation -> it[Organizations.contactInformation] = contactInformation }
        } > 0
    }

    suspend fun deleteOrganization(organizationId: Int): Boolean = dbQuery {
        Organizations.deleteWhere { Organizations.organizationId eq organizationId } > 0
    }

    private fun toOrganizationResponse(row: ResultRow): OrganizationResponse {
        return OrganizationResponse(
            organizationId = row[Organizations.organizationId],
            name = row[Organizations.name],
            contactInformation = row[Organizations.contactInformation]
        )
    }
}
