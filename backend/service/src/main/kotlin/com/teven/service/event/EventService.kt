package com.teven.service.event

import com.teven.api.model.event.CreateEventRequest
import com.teven.api.model.event.EventResponse
import com.teven.data.event.EventDao

class EventService(private val eventDao: EventDao) {
  suspend fun createEvent(createEventRequest: CreateEventRequest): EventResponse {
    if (createEventRequest.title.isBlank()) {
      throw IllegalArgumentException("Event title cannot be empty")
    }
    // TODO: Add more business logic and validation here
    return eventDao.createEvent(createEventRequest)
  }

  suspend fun getAllEvents(): List<EventResponse> {
    return eventDao.getAllEvents()
  }

  suspend fun getEventById(eventId: Int): EventResponse? {
    return eventDao.getEventById(eventId)
  }

  suspend fun updateEvent(
    eventId: Int,
    updateEventRequest: com.teven.api.model.event.UpdateEventRequest,
  ): Boolean {
    return eventDao.updateEvent(eventId, updateEventRequest)
  }

  suspend fun deleteEvent(eventId: Int): Boolean {
    return eventDao.deleteEvent(eventId)
  }

  suspend fun assignStaffToEvent(eventId: Int, userId: Int): Boolean {
    return eventDao.assignStaffToEvent(eventId, userId)
  }

  suspend fun removeStaffFromEvent(eventId: Int, userId: Int): Boolean {
    return eventDao.removeStaffFromEvent(eventId, userId)
  }

  suspend fun rsvpToEvent(eventId: Int, userId: Int, availability: String): Boolean {
    return eventDao.rsvpToEvent(eventId, userId, availability)
  }
}
