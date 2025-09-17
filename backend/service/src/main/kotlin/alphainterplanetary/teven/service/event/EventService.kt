package alphainterplanetary.teven.service.event

import alphainterplanetary.teven.api.model.event.CreateEventRequest
import alphainterplanetary.teven.api.model.event.EventResponse
import alphainterplanetary.teven.api.model.event.UpdateEventRequest
import alphainterplanetary.teven.core.security.AuthContext
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.data.event.EventDao

class EventService(private val eventDao: EventDao) {
  suspend fun createEvent(
    authContext: AuthContext,
    createEventRequest: CreateEventRequest,
  ): EventResponse {
    if (createEventRequest.title.isBlank()) {
      throw IllegalArgumentException("Event title cannot be empty")
    }

    val organizationIdToUse = if (authContext.hasPermission(Permission.MANAGE_EVENTS_GLOBAL)) {
      createEventRequest.organizationId
        ?: throw IllegalArgumentException("organizationId is required for MANAGE_EVENTS_GLOBAL users")
    } else {
      authContext.organizationId
    }

    // Create a new request with the determined organizationId
    val requestWithOrgId = createEventRequest.copy(organizationId = organizationIdToUse)

    return eventDao.createEvent(requestWithOrgId)
  }

  suspend fun getEvents(
    authContext: AuthContext,
    startDate: String?,
    endDate: String?,
    limit: Int?,
    offset: Long?,
    sortOrder: String?,
  ): List<EventResponse> {
    val organizationId = if (authContext.hasPermission(Permission.VIEW_EVENTS_GLOBAL)) {
      null
    } else {
      authContext.organizationId
    }
    return eventDao.getEvents(
      organizationId = organizationId,
      startDate = startDate,
      endDate = endDate,
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
    // Check if the event belongs to the user's organization or if the user has MANAGE_EVENTS_GLOBAL
    val event = eventDao.getEventById(eventId)
      ?: return false // Event not found

    if (!authContext.hasPermission(Permission.MANAGE_EVENTS_GLOBAL) && event.organization.organizationId != authContext.organizationId) {
      throw IllegalAccessException("User not authorized to update events outside their organization")
    }

    // If MANAGE_EVENTS_GLOBAL, allow organizationId to be updated, otherwise ensure it's not changed
    val requestWithOrgId = if (authContext.hasPermission(Permission.MANAGE_EVENTS_GLOBAL)) {
      updateEventRequest
    } else {
      if (updateEventRequest.organizationId != null && updateEventRequest.organizationId != event.organization.organizationId) {
        throw IllegalArgumentException("Non-MANAGE_EVENTS_GLOBAL users cannot change event organizationId")
      }
      updateEventRequest.copy(organizationId = event.organization.organizationId)
    }

    return eventDao.updateEvent(eventId, requestWithOrgId)
  }

  suspend fun deleteEvent(authContext: AuthContext, eventId: Int): Boolean {
    val event = eventDao.getEventById(eventId)
      ?: return false // Event not found

    if (!authContext.hasPermission(Permission.MANAGE_EVENTS_GLOBAL) && event.organization.organizationId != authContext.organizationId) {
      throw IllegalAccessException("User not authorized to delete events outside their organization")
    }
    return eventDao.deleteEvent(eventId)
  }

  suspend fun assignStaffToEvent(authContext: AuthContext, eventId: Int, userId: Int): Boolean {
    val event = eventDao.getEventById(eventId)
      ?: throw IllegalArgumentException("Event not found")

    if (!authContext.hasPermission(Permission.MANAGE_EVENTS_ORGANIZATION) && event.organization.organizationId != authContext.organizationId) {
      throw IllegalAccessException("User not authorized to assign staff to events outside their organization")
    }
    return eventDao.assignStaffToEvent(eventId, userId)
  }

  suspend fun removeStaffFromEvent(authContext: AuthContext, eventId: Int, userId: Int): Boolean {
    val event = eventDao.getEventById(eventId)
      ?: throw IllegalArgumentException("Event not found")

    if (!authContext.hasPermission(Permission.MANAGE_EVENTS_ORGANIZATION) && event.organization.organizationId != authContext.organizationId) {
      throw IllegalAccessException("User not authorized to remove staff from events outside their organization")
    }
    return eventDao.removeStaffFromEvent(eventId, userId)
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
}
