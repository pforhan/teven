package alphainterplanetary.teven.service.event

import alphainterplanetary.teven.api.model.event.CreateEventRequest
import alphainterplanetary.teven.api.model.event.EventResponse
import alphainterplanetary.teven.api.model.event.UpdateEventRequest
import alphainterplanetary.teven.core.BadRequestException
import alphainterplanetary.teven.core.security.AuthContext
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.data.event.EventDao
import alphainterplanetary.teven.api.model.common.PaginatedResponse
import alphainterplanetary.teven.service.organization.OrganizationService
import java.time.Instant
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeParseException

class EventService(
  private val eventDao: EventDao,
  private val organizationService: OrganizationService,
) {
  suspend fun createEvent(
    authContext: AuthContext,
    createEventRequest: CreateEventRequest,
  ): EventResponse {
    if (createEventRequest.title.isBlank()) {
      throw IllegalArgumentException("Event title cannot be empty")
    }

    val organizationIdToUse = if (authContext.hasPermission(Permission.MANAGE_EVENTS_GLOBAL)) {
      createEventRequest.organizationId
    } else {
      authContext.organizationId
    }

    val requestWithOrgId = createEventRequest.copy(organizationId = organizationIdToUse)

    val timezone = resolveZone(requestWithOrgId.timezone)
    val startsAt =
        parseInstant(requestWithOrgId.startsAt) ?: throw BadRequestException("Invalid event startsAt")

    return eventDao.createEvent(requestWithOrgId, startsAt, timezone)
  }

  suspend fun getEvents(
    authContext: AuthContext,
    startDate: String?,
    endDate: String?,
    search: String?,
    limit: Int?,
    offset: Long?,
    sortOrder: String?,
    organizationId: Int?,
    timezone: String?,
  ): PaginatedResponse<EventResponse> {
    val organizationIdToUse = if (authContext.hasPermission(Permission.VIEW_EVENTS_GLOBAL)) {
      organizationId
    } else {
      authContext.organizationId
    }
    val zone = resolveZone(timezone ?: defaultZone(organizationIdToUse ?: authContext.organizationId, authContext))
    val startInstant =
        startDate?.let { LocalDate.parse(it).atStartOfDay(ZoneId.of(zone)).toInstant() }
    val endExclusiveInstant =
        endDate?.let { LocalDate.parse(it).plusDays(1).atStartOfDay(ZoneId.of(zone)).toInstant() }

    return eventDao.getEvents(
      organizationId = organizationIdToUse,
      startInstant = startInstant,
      endExclusiveInstant = endExclusiveInstant,
      search = search,
      limit = limit,
      offset = offset,
      sortOrder = sortOrder,
    )
  }

  suspend fun getEventById(authContext: AuthContext, eventId: Int): EventResponse? {
    val event = eventDao.getEventById(eventId)

    return if (event != null && !authContext.hasPermission(Permission.VIEW_EVENTS_GLOBAL) && event.organization.organizationId != authContext.organizationId) {
      null // Not found or not authorized
    } else {
      event
    }
  }

  suspend fun updateEvent(
    authContext: AuthContext,
    eventId: Int,
    updateEventRequest: UpdateEventRequest,
  ): Boolean {
    val event = eventDao.getEventById(eventId)
      ?: return false // Event not found

    if (!authContext.hasPermission(Permission.MANAGE_EVENTS_GLOBAL) && event.organization.organizationId != authContext.organizationId) {
      throw IllegalAccessException("User not authorized to update events outside their organization")
    }

    val requestWithOrgId =
        if (authContext.hasPermission(Permission.MANAGE_EVENTS_GLOBAL)) {
          updateEventRequest
        } else {
          if (updateEventRequest.organizationId != null && updateEventRequest.organizationId != event.organization.organizationId) {
            throw IllegalArgumentException("Non-MANAGE_EVENTS_GLOBAL users cannot change event organizationId")
          }
          updateEventRequest.copy(organizationId = event.organization.organizationId)
        }

    val updateStartsAt = updateEventRequest.startsAt
    val updateTimezone = updateEventRequest.timezone
    val (startsAt, timezone) =
        when {
          updateStartsAt != null && updateTimezone != null -> {
            val resolvedZone = resolveZone(updateTimezone)
            val instant =
                parseInstant(updateStartsAt) ?: throw BadRequestException("Invalid event startsAt")
            instant to resolvedZone
          }
          updateStartsAt == null && updateTimezone == null -> {
            Instant.parse(event.startsAt) to event.timezone
          }
          else -> throw BadRequestException("Event startsAt and timezone must be sent together")
        }

    return eventDao.updateEvent(eventId, requestWithOrgId, startsAt, timezone)
  }

  suspend fun deleteEvent(authContext: AuthContext, eventId: Int): Boolean {
    val event = eventDao.getEventById(eventId)
      ?: return false // Event not found

    if (!authContext.hasPermission(Permission.MANAGE_EVENTS_GLOBAL) && event.organization.organizationId != authContext.organizationId) {
      throw IllegalAccessException("User not authorized to delete events outside their organization")
    }
    return eventDao.deleteEvent(eventId)
  }

  suspend fun rsvpToEvent(
    authContext: AuthContext,
    eventId: Int,
    userId: Int,
    availability: String,
  ): Boolean {
    val event = eventDao.getEventById(eventId)
      ?: throw IllegalArgumentException("Event not found")

    if (!authContext.hasPermission(Permission.MANAGE_EVENTS_ORGANIZATION) && event.organization.organizationId != authContext.organizationId) {
      throw IllegalAccessException("User not authorized to RSVP to events outside their organization")
    }
    return eventDao.rsvpToEvent(eventId, userId, availability)
  }

  suspend fun getRequestedRsvpEventsForUser(userId: Int): List<EventResponse> {
    return eventDao.getRequestedRsvpEventsForUser(userId)
  }

  private fun resolveZone(timezone: String?): String {
    val zone = timezone ?: DEFAULT_TIME_ZONE
    if (!ZoneId.getAvailableZoneIds().contains(zone)) {
      throw BadRequestException("Unknown time zone: $zone")
    }
    return zone
  }

  private suspend fun defaultZone(organizationId: Int, authContext: AuthContext): String {
    val organization = organizationService.getOrganizationZone(organizationId)
    return organization ?: DEFAULT_TIME_ZONE
  }

  private fun parseInstant(raw: String): Instant? {
    return try {
      OffsetDateTime.parse(raw).toInstant()
    } catch (e: DateTimeParseException) {
      null
    }
  }

}

private const val DEFAULT_TIME_ZONE = "UTC"
