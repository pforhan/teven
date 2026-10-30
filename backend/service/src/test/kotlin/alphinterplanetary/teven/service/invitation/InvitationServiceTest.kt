package alphainterplanetary.teven.service.invitation

import alphainterplanetary.teven.api.model.invitation.AcceptInvitationRequest
import alphainterplanetary.teven.service.organization.OrganizationService
import alphainterplanetary.teven.core.service.RoleService
import alphainterplanetary.teven.core.service.UserService
import alphainterplanetary.teven.core.user.Invitation
import alphainterplanetary.teven.data.invitation.InvitationDao
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test
import java.time.Clock
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneOffset

class InvitationServiceTest {

  private val invitationDao: InvitationDao = mockk()
  private val roleService: RoleService = mockk()
  private val userService: UserService = mockk()
  private val organizationService: OrganizationService = mockk()
  private val clock: Clock = Clock.fixed(Instant.parse("2026-10-30T12:00:00Z"), ZoneOffset.UTC)
  private val invitationService =
    InvitationService(invitationDao, roleService, userService, organizationService, clock)

  private fun invitation(expiringAt: LocalDateTime): Invitation =
    Invitation(
      id = 1,
      organizationId = 1,
      organizationName = "Test Org",
      roleId = 1,
      roleName = "Organizer",
      token = "token",
      expiresAt = expiringAt,
      usedByUserId = null,
      createdAt = LocalDateTime.ofInstant(Instant.parse("2026-10-23T12:00:00Z"), ZoneOffset.UTC),
      note = null,
    )

  @Test
  fun `validate invitation should accept a token that is not expired`() = runBlocking {
    coEvery { invitationDao.getInvitationByToken("token") } returns invitation(
      expiringAt = LocalDateTime.ofInstant(Instant.parse("2026-11-06T12:00:00Z"), ZoneOffset.UTC),
    )

    val result = invitationService.validateInvitation("token")

    assertNotNull(result)
  }

  @Test
  fun `validate invitation should reject a token that has expired`() = runBlocking {
    coEvery { invitationDao.getInvitationByToken("token") } returns invitation(
      expiringAt = LocalDateTime.ofInstant(Instant.parse("2026-10-23T12:00:00Z"), ZoneOffset.UTC),
    )

    val result = invitationService.validateInvitation("token")

    assertNull(result)
  }

  @Test
  fun `accept invitation should reject an expired invitation`() = runBlocking {
    coEvery { invitationDao.getInvitationByToken("token") } returns invitation(
      expiringAt = LocalDateTime.ofInstant(Instant.parse("2026-10-23T12:00:00Z"), ZoneOffset.UTC),
    )

    val response = invitationService.acceptInvitation(
      AcceptInvitationRequest(
        token = "token",
        username = "newuser",
        password = "password",
        email = "new@example.com",
        displayName = "New User",
      ),
    )

    assertFalse(response.success)
    assertEquals("Invitation has expired.", response.message)
  }
}
