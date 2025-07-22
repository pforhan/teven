
package com.teven.service.event

import com.teven.api.model.event.CreateEventRequest
import com.teven.api.model.event.EventResponse
import com.teven.data.event.EventDao

class EventService(private val eventDao: EventDao) {
    fun createEvent(createEventRequest: CreateEventRequest): EventResponse {
        // TODO: Add business logic, e.g., validation
        return eventDao.createEvent(createEventRequest)
    }

    fun getAllEvents(): List<EventResponse> {
        return eventDao.getAllEvents()
    }

    fun getEventById(eventId: Int): EventResponse? {
        return eventDao.getEventById(eventId)
    }

    fun updateEvent(eventId: Int, updateEventRequest: com.teven.api.model.event.UpdateEventRequest): Boolean {
        return eventDao.updateEvent(eventId, updateEventRequest)
    }

    fun deleteEvent(eventId: Int): Boolean {
        return eventDao.deleteEvent(eventId)
    }

    fun assignStaffToEvent(eventId: Int, userId: Int): Boolean {
        return eventDao.assignStaffToEvent(eventId, userId)
    }

    fun removeStaffFromEvent(eventId: Int, userId: Int): Boolean {
        return eventDao.removeStaffFromEvent(eventId, userId)
    }

    fun rsvpToEvent(eventId: Int, userId: Int, availability: String): Boolean {
        return eventDao.rsvpToEvent(eventId, userId, availability)
    }
}
