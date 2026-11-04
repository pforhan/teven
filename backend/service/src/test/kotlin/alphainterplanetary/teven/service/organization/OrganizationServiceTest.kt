package alphainterplanetary.teven.service.organization

import alphainterplanetary.teven.api.model.auth.LoggedInContextResponse
import alphainterplanetary.teven.api.model.organization.CreateOrganizationRequest
import alphainterplanetary.teven.api.model.organization.OrganizationResponse
import alphainterplanetary.teven.api.model.organization.UpdateOrganizationRequest
import alphainterplanetary.teven.api.model.user.UserResponse
import alphainterplanetary.teven.core.BadRequestException
import alphainterplanetary.teven.core.security.AuthorizationException
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.core.service.UserService
import alphainterplanetary.teven.data.organization.OrganizationDao
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class OrganizationServiceTest {

  private val organizationDao: OrganizationDao = mockk()
  private val userService: UserService = mockk()
  private val organizationService = OrganizationService(organizationDao, userService)

  private fun callerContext(
    permissions: List<Permission>,
    organizationId: Int = 1,
  ): LoggedInContextResponse {
    return LoggedInContextResponse(
      user = UserResponse(
        userId = 10,
        username = "caller",
        email = "caller@example.com",
        displayName = "Caller",
        roles = listOf("Organizer"),
        organization = OrganizationResponse(
          organizationId = organizationId,
          name = "Caller Org",
          contactInformation = "contact@example.com",
          timezone = "UTC",
        ),
      ),
      permissions = permissions.map { it.name },
    )
  }

  @Test
  fun `create organization keeps the submitted time zone`() = runBlocking {
    coEvery { organizationDao.createOrganization(any(), any()) } returns OrganizationResponse(
      organizationId = 1,
      name = "New Org",
      contactInformation = "contact@example.com",
      timezone = "America/New_York",
    )

    val result = organizationService.createOrganization(
      CreateOrganizationRequest(
        name = "New Org",
        contactInformation = "contact@example.com",
        timezone = "America/New_York",
      ),
    )

    assertEquals("America/New_York", result.timezone)
    coVerify { organizationDao.createOrganization(any(), "America/New_York") }
  }

  @Test
  fun `create organization rejects an unknown time zone`() = runBlocking {
    coEvery { organizationDao.createOrganization(any(), any()) } throws BadRequestException("Unknown time zone: Mars/Olympus")

    val exception = runCatching {
      organizationService.createOrganization(
        CreateOrganizationRequest(
          name = "New Org",
          contactInformation = "contact@example.com",
          timezone = "Mars/Olympus",
        ),
      )
    }.exceptionOrNull()

    assertNotNull(exception)
    assertEquals(BadRequestException::class.java, exception!!.javaClass)
  }

  @Test
  fun `update organization applies the submitted time zone`() = runBlocking {
    coEvery { userService.getUserContext(any()) } returns callerContext(listOf(Permission.MANAGE_ORGANIZATIONS_GLOBAL))
    coEvery { organizationDao.updateOrganization(any(), any()) } returns true

    val result = organizationService.updateOrganization(
      organizationId = 1,
      request = UpdateOrganizationRequest(
        name = "New Org",
        contactInformation = "contact@example.com",
        timezone = "Europe/Berlin",
      ),
      callerId = 10,
    )

    assertTrue(result)
    coVerify {
      organizationDao.updateOrganization(
        1,
        UpdateOrganizationRequest(
          name = "New Org",
          contactInformation = "contact@example.com",
          timezone = "Europe/Berlin",
        ),
      )
    }
  }

  @Test
  fun `update organization rejects an unknown time zone`() = runBlocking {
    coEvery { userService.getUserContext(any()) } returns callerContext(listOf(Permission.MANAGE_ORGANIZATIONS_GLOBAL))
    coEvery { organizationDao.updateOrganization(any(), any()) } throws BadRequestException("Unknown time zone: Mars/Olympus")

    val exception = runCatching {
      organizationService.updateOrganization(
        organizationId = 1,
        request = UpdateOrganizationRequest(
          name = "New Org",
          contactInformation = "contact@example.com",
          timezone = "Mars/Olympus",
        ),
        callerId = 10,
      )
    }.exceptionOrNull()

    assertNotNull(exception)
    assertEquals(BadRequestException::class.java, exception!!.javaClass)
  }

  @Test
  fun `update organization allows an organization manager to update their own organization`() = runBlocking {
    coEvery { userService.getUserContext(any()) } returns callerContext(listOf(Permission.MANAGE_ORGANIZATION))
    coEvery { organizationDao.updateOrganization(any(), any()) } returns true

    val result = organizationService.updateOrganization(
      organizationId = 1,
      request = UpdateOrganizationRequest(
        name = "New Org",
        contactInformation = "contact@example.com",
        timezone = "Europe/Berlin",
      ),
      callerId = 10,
    )

    assertTrue(result)
  }

  @Test
  fun `update organization rejects an organization manager updating another organization`() = runBlocking {
    coEvery { userService.getUserContext(any()) } returns callerContext(listOf(Permission.MANAGE_ORGANIZATION), organizationId = 2)

    val exception = runCatching {
      organizationService.updateOrganization(
        organizationId = 1,
        request = UpdateOrganizationRequest(
          name = "New Org",
          contactInformation = "contact@example.com",
          timezone = "Europe/Berlin",
        ),
        callerId = 10,
      )
    }.exceptionOrNull()

    assertNotNull(exception)
    assertEquals(AuthorizationException::class.java, exception!!.javaClass)
  }

  @Test
  fun `update organization rejects a caller without the manage permission`() = runBlocking {
    coEvery { userService.getUserContext(any()) } returns callerContext(emptyList())

    val exception = runCatching {
      organizationService.updateOrganization(
        organizationId = 1,
        request = UpdateOrganizationRequest(
          name = "New Org",
          contactInformation = "contact@example.com",
          timezone = "Europe/Berlin",
        ),
        callerId = 10,
      )
    }.exceptionOrNull()

    assertNotNull(exception)
    assertEquals(AuthorizationException::class.java, exception!!.javaClass)
  }

  @Test
  fun `get organization allows an organization manager to read their own organization`() = runBlocking {
    coEvery { userService.getUserContext(any()) } returns callerContext(listOf(Permission.MANAGE_ORGANIZATION))
    coEvery { organizationDao.getOrganizationById(1) } returns OrganizationResponse(
      organizationId = 1,
      name = "Caller Org",
      contactInformation = "contact@example.com",
      timezone = "UTC",
    )

    val result = organizationService.getOrganizationById(organizationId = 1, callerId = 10)

    assertNotNull(result)
  }

  @Test
  fun `get organization rejects an organization manager reading another organization`() = runBlocking {
    coEvery { userService.getUserContext(any()) } returns callerContext(listOf(Permission.MANAGE_ORGANIZATION), organizationId = 2)

    val exception = runCatching {
      organizationService.getOrganizationById(organizationId = 1, callerId = 10)
    }.exceptionOrNull()

    assertNotNull(exception)
    assertEquals(AuthorizationException::class.java, exception!!.javaClass)
  }
}
