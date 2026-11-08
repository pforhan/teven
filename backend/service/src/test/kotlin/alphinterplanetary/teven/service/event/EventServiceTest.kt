package alphainterplanetary.teven.service.event

import alphainterplanetary.teven.api.model.common.PaginatedResponse
import alphainterplanetary.teven.api.model.event.CreateEventRequest
import alphainterplanetary.teven.api.model.event.EventResponse
import alphainterplanetary.teven.api.model.event.StaffInviteDetails
import alphainterplanetary.teven.api.model.event.UpdateEventRequest
import alphainterplanetary.teven.api.model.organization.OrganizationResponse
import alphainterplanetary.teven.core.BadRequestException
import alphainterplanetary.teven.core.security.AuthContext
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.data.event.EventDao
import alphainterplanetary.teven.service.organization.OrganizationService
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Test
import java.time.Instant

class EventServiceTest {

  private val eventDao: EventDao = mockk()
  private val organizationService: OrganizationService = mockk()
  private val eventService = EventService(eventDao, organizationService)

  private val authContext =
      AuthContext(userId = 1, organizationId = 1, permissions = setOf(Permission.MANAGE_EVENTS_GLOBAL))

  private fun eventResponse(): EventResponse =
      EventResponse(
        eventId = 1,
        title = "Launch",
        date = "2026-03-04",
        time = "09:00:00",
        startsAt = "2026-03-04T08:00:00Z",
        timezone = "Europe/Berlin",
        durationMinutes = 60,
        location = null,
        latitude = null,
        longitude = null,
        formattedAddress = null,
        description = null,
        inventoryItems = emptyList(),
        customer = null,
        rsvps = emptyList(),
        organization =
            OrganizationResponse(
              organizationId = 1,
              name = "Acme",
              contactInformation = "contact@example.com",
              timezone = "Europe/Berlin",
            ),
        openInvitation = false,
        numberOfStaffNeeded = 0,
      )

  @Test
  fun `create event with an instant and a zone stores the instant and the zone`() = runBlocking {
    coEvery { eventDao.createEvent(any(), any(), any()) } returns eventResponse()

    val response =
        eventService.createEvent(
          authContext = authContext,
          createEventRequest =
              CreateEventRequest(
                title = "Launch",
                durationMinutes = 60,
                inventoryItems = emptyList(),
                staffInvites = StaffInviteDetails(numberOfStaffNeeded = 2),
                organizationId = 1,
                startsAt = "2026-03-04T08:00:00Z",
                timezone = "Europe/Berlin",
              ),
        )

    assertEquals("Europe/Berlin", response.timezone)
    coVerify { eventDao.createEvent(any(), Instant.parse("2026-03-04T08:00:00Z"), "Europe/Berlin") }
  }

  @Test
  fun `create event with a legacy wall clock resolves it in the organization zone`() = runBlocking {
    coEvery { eventDao.createEvent(any(), any(), any()) } returns eventResponse()
    coEvery { organizationService.getOrganizationZone(1) } returns "Europe/Berlin"

    eventService.createEvent(
      authContext = authContext,
      createEventRequest =
          CreateEventRequest(
            title = "Launch",
            durationMinutes = 60,
            inventoryItems = emptyList(),
            staffInvites = StaffInviteDetails(numberOfStaffNeeded = 2),
            organizationId = 1,
            date = "2026-03-04",
            time = "09:00",
          ),
    )

    coVerify { eventDao.createEvent(any(), Instant.parse("2026-03-04T08:00:00Z"), "Europe/Berlin") }
  }

  @Test
  fun `create event rejects a naive instant`() = runBlocking {
    val exception =
        runCatching {
          eventService.createEvent(
            authContext = authContext,
            createEventRequest =
                CreateEventRequest(
                  title = "Launch",
                  durationMinutes = 60,
                  inventoryItems = emptyList(),
                  staffInvites = StaffInviteDetails(numberOfStaffNeeded = 2),
                  organizationId = 1,
                  startsAt = "2026-03-04T09:00:00",
                  timezone = "Europe/Berlin",
                ),
          )
        }.exceptionOrNull()

    assertNotNull(exception)
    assertEquals(BadRequestException::class.java, exception!!.javaClass)
  }

  @Test
  fun `create event rejects an unknown zone`() = runBlocking {
    val exception =
        runCatching {
          eventService.createEvent(
            authContext = authContext,
            createEventRequest =
                CreateEventRequest(
                  title = "Launch",
                  durationMinutes = 60,
                  inventoryItems = emptyList(),
                  staffInvites = StaffInviteDetails(numberOfStaffNeeded = 2),
                  organizationId = 1,
                  startsAt = "2026-03-04T08:00:00Z",
                  timezone = "Mars/Olympus_Mons",
                ),
          )
        }.exceptionOrNull()

    assertNotNull(exception)
    assertEquals(BadRequestException::class.java, exception!!.javaClass)
  }

  @Test
  fun `get events converts a local date range into an instant range in the requested zone`() = runBlocking {
    coEvery { eventDao.getEvents(any(), any(), any(), any(), any(), any(), any()) } returns
        PaginatedResponse(items = emptyList(), total = 0, offset = 0, limit = 0)

    val result =
        eventService.getEvents(
          authContext = authContext,
          startDate = "2026-03-04",
          endDate = "2026-03-05",
          search = null,
          limit = null,
          offset = null,
          sortOrder = "asc",
          organizationId = null,
          timezone = "Europe/Berlin",
        )

    assertNotNull(result)
    coVerify {
      eventDao.getEvents(
        1,
        Instant.parse("2026-03-03T23:00:00Z"),
        Instant.parse("2026-03-05T23:00:00Z"),
        null,
        null,
        null,
        "asc",
      )
    }
  }

  @Test
  fun `update event sends a new instant and zone together`() = runBlocking {
    coEvery { eventDao.getEventById(1) } returns eventResponse()
    coEvery { eventDao.updateEvent(any(), any(), any(), any()) } returns true

    val updated =
        eventService.updateEvent(
          authContext = authContext,
          eventId = 1,
          updateEventRequest =
              UpdateEventRequest(
                startsAt = "2026-03-04T10:00:00Z",
                timezone = "America/New_York",
              ),
        )

    assertEquals(true, updated)
    coVerify { eventDao.updateEvent(1, any(), Instant.parse("2026-03-04T10:00:00Z"), "America/New_York") }
  }

  @Test
  fun `update event rejects a lone starts at`() = runBlocking {
    coEvery { eventDao.getEventById(1) } returns eventResponse()

    val exception =
        runCatching {
          eventService.updateEvent(
            authContext = authContext,
            eventId = 1,
            updateEventRequest = UpdateEventRequest(startsAt = "2026-03-04T10:00:00Z"),
          )
        }.exceptionOrNull()

    assertNotNull(exception)
    assertEquals(BadRequestException::class.java, exception!!.javaClass)
  }

  @Test
  fun `update event with a legacy wall clock keeps the event zone when no zone is sent`() = runBlocking {
    coEvery { eventDao.getEventById(1) } returns eventResponse()
    coEvery { eventDao.updateEvent(any(), any(), any(), any()) } returns true

    val updated =
        eventService.updateEvent(
          authContext = authContext,
          eventId = 1,
          updateEventRequest = UpdateEventRequest(date = "2026-03-05", time = "18:00"),
        )

    assertEquals(true, updated)
    coVerify { eventDao.updateEvent(1, any(), Instant.parse("2026-03-05T17:00:00Z"), "Europe/Berlin") }
  }
}
