package alphainterplanetary.teven.service.organization

import alphainterplanetary.teven.api.model.common.PaginatedResponse
import alphainterplanetary.teven.api.model.organization.CreateOrganizationRequest
import alphainterplanetary.teven.api.model.organization.OrganizationResponse
import alphainterplanetary.teven.api.model.organization.UpdateOrganizationRequest
import alphainterplanetary.teven.core.BadRequestException
import alphainterplanetary.teven.core.security.AuthorizationException
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.core.service.UserService
import alphainterplanetary.teven.data.organization.OrganizationDao
import io.ktor.http.HttpStatusCode
import java.time.ZoneId

class OrganizationService(
  private val organizationDao: OrganizationDao,
  private val userService: UserService,
) {
  suspend fun getOrganizations(
    search: String? = null,
    limit: Int? = null,
    offset: Long? = null,
    sortBy: String? = null,
    sortOrder: String? = null,
  ): PaginatedResponse<OrganizationResponse> {
    return organizationDao.getOrganizations(
      search = search,
      limit = limit,
      offset = offset,
      sortBy = sortBy,
      sortOrder = sortOrder
    )
  }

  suspend fun createOrganization(request: CreateOrganizationRequest): OrganizationResponse {
    val timezone = resolveTimezone(request.timezone)
    return organizationDao.createOrganization(request, timezone)
  }

  suspend fun getAllOrganizations(): List<OrganizationResponse> {
    return organizationDao.getAllOrganizations()
  }

  suspend fun getOrganizationById(organizationId: Int, callerId: Int): OrganizationResponse? {
    if (!canAccess(callerId, organizationId, Permission.VIEW_ORGANIZATIONS_GLOBAL, Permission.MANAGE_ORGANIZATION)) {
      throw AuthorizationException(
        code = HttpStatusCode.Forbidden,
        message = "User does not have permission to view this organization."
      )
    }
    return organizationDao.getOrganizationById(organizationId)
  }

  suspend fun getOrganizationZone(organizationId: Int): String? =
    organizationDao.getOrganizationById(organizationId)?.timezone

  suspend fun updateOrganization(organizationId: Int, request: UpdateOrganizationRequest, callerId: Int): Boolean {
    if (!canAccess(callerId, organizationId, Permission.MANAGE_ORGANIZATIONS_GLOBAL, Permission.MANAGE_ORGANIZATION)) {
      throw AuthorizationException(
        code = HttpStatusCode.Forbidden,
        message = "User does not have permission to update this organization."
      )
    }
    resolveTimezone(request.timezone)
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

  /**
   * Whether the caller may act on [organizationId]: they hold the global
   * permission, or they hold the organization-scoped one and the organization is
   * theirs. Task 7.16 gave the organization-scoped permission to the Organizer
   * as its own door — today, setting their organization's home time zone — so the
   * scoping lives here rather than in a route-level permission alone.
   */
  private suspend fun canAccess(
    callerId: Int,
    organizationId: Int,
    globalPermission: Permission,
    organizationScopedPermission: Permission,
  ): Boolean {
    val context = userService.getUserContext(callerId)
    if (context.permissions.contains(globalPermission.name)) {
      return true
    }
    if (!context.permissions.contains(organizationScopedPermission.name)) {
      return false
    }
    return context.user.organization.organizationId == organizationId
  }

  /**
   * An organization has a home time zone, and an event is read in the zone it
   * was scheduled in. The zone travels with the organization now (task 7.15);
   * it is required on create and update, and the server owns the validation.
   */
  private fun resolveTimezone(timezone: String): String {
    if (!ZoneId.getAvailableZoneIds().contains(timezone)) {
      throw BadRequestException("Unknown time zone: $timezone")
    }
    return timezone
  }
}
