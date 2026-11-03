package alphainterplanetary.teven.service.organization

import alphainterplanetary.teven.api.model.organization.CreateOrganizationRequest
import alphainterplanetary.teven.api.model.organization.OrganizationResponse
import alphainterplanetary.teven.api.model.organization.UpdateOrganizationRequest
import alphainterplanetary.teven.core.BadRequestException
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
    coEvery { organizationDao.updateOrganization(any(), any()) } returns true

    val result = organizationService.updateOrganization(
      1,
      UpdateOrganizationRequest(
        name = "New Org",
        contactInformation = "contact@example.com",
        timezone = "Europe/Berlin",
      ),
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
    coEvery { organizationDao.updateOrganization(any(), any()) } throws BadRequestException("Unknown time zone: Mars/Olympus")

    val exception = runCatching {
      organizationService.updateOrganization(
        1,
        UpdateOrganizationRequest(
          name = "New Org",
          contactInformation = "contact@example.com",
          timezone = "Mars/Olympus",
        ),
      )
    }.exceptionOrNull()

    assertNotNull(exception)
    assertEquals(BadRequestException::class.java, exception!!.javaClass)
  }
}
