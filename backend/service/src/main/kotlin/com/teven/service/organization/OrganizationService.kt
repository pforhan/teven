package com.teven.service.organization

import com.teven.api.model.organization.CreateOrganizationRequest
import com.teven.api.model.organization.OrganizationResponse
import com.teven.api.model.organization.UpdateOrganizationRequest
import com.teven.data.organization.OrganizationDao

class OrganizationService(private val organizationDao: OrganizationDao) {
  suspend fun createOrganization(request: CreateOrganizationRequest): OrganizationResponse {
    return organizationDao.createOrganization(request)
  }

  suspend fun getAllOrganizations(): List<OrganizationResponse> {
    return organizationDao.getAllOrganizations()
  }

  suspend fun getOrganizationById(organizationId: Int): OrganizationResponse? {
    return organizationDao.getOrganizationById(organizationId)
  }

  suspend fun updateOrganization(organizationId: Int, request: UpdateOrganizationRequest): Boolean {
    return organizationDao.updateOrganization(organizationId, request)
  }

  suspend fun deleteOrganization(organizationId: Int): Boolean {
    return organizationDao.deleteOrganization(organizationId)
  }
}
