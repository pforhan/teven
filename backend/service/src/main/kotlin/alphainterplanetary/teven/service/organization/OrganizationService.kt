package alphainterplanetary.teven.service.organization

import alphainterplanetary.teven.api.model.organization.CreateOrganizationRequest
import alphainterplanetary.teven.api.model.organization.OrganizationResponse
import alphainterplanetary.teven.api.model.organization.UpdateOrganizationRequest
import alphainterplanetary.teven.core.security.AuthorizationException
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.core.service.UserService
import alphainterplanetary.teven.data.organization.OrganizationDao
import io.ktor.http.HttpStatusCode

class OrganizationService(
  private val organizationDao: OrganizationDao,
  private val userService: UserService,
) {
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

  suspend fun assignUserToOrganization(userId: Int, organizationId: Int, callerId: Int): Boolean {
    val callerPermissions = userService.getUserContext(callerId).permissions

    if (callerPermissions.contains(Permission.MANAGE_USERS_GLOBAL.name)) {
      return organizationDao.assignUserToOrganization(userId, organizationId)
    }

    if (callerPermissions.contains(Permission.MANAGE_USERS_ORGANIZATION.name)) {
      val callerOrganizationId =
        userService.getUserContext(callerId).user.organization.organizationId
      if (callerOrganizationId == organizationId) {
        return organizationDao.assignUserToOrganization(userId, organizationId)
      }
    }

    throw AuthorizationException(
      code = HttpStatusCode.Forbidden,
      message = "User does not have permission to assign users to this organization."
    )
  }
}
