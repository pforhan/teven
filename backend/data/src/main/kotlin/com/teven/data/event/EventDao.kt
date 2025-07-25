package com.teven.data.event

import com.teven.api.model.event.CreateEventRequest
import com.teven.api.model.event.EventResponse
import com.teven.api.model.event.RsvpStatus
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.transactions.transaction
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.select
import org.jetbrains.exposed.sql.update
import org.jetbrains.exposed.sql.deleteWhere
import org.jetbrains.exposed.sql.and
import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
import org.jetbrains.exposed.sql.ResultRow

class EventDao {
    private fun toEventResponse(row: ResultRow): EventResponse {
        val eventId = row[Events.id].value

        val inventoryIds = EventInventory.select { EventInventory.eventId eq eventId }.map { it[EventInventory.inventoryId].value }

        val assignedStaffIds = EventStaff.select { EventStaff.eventId eq eventId }.map { it[EventStaff.userId].value }

        val rsvps = Rsvps.select { Rsvps.eventId eq eventId }.map { RsvpStatus(it[Rsvps.userId].value, it[Rsvps.availability]) }

        return EventResponse(
            eventId = eventId,
            title = row[Events.title],
            date = row[Events.date],
            time = row[Events.time],
            location = row[Events.location],
            description = row[Events.description],
            inventoryIds = inventoryIds,
            customerId = row[Events.customerId],
            assignedStaffIds = assignedStaffIds,
            rsvps = rsvps
        )
    }

    fun createEvent(createEventRequest: CreateEventRequest): EventResponse {
        return transaction {
            val id = Events.insert {
                it[title] = createEventRequest.title
                it[date] = createEventRequest.date
                it[time] = createEventRequest.time
                it[location] = createEventRequest.location
                it[description] = createEventRequest.description
                it[customerId] = createEventRequest.customerId
                it[openInvitation] = createEventRequest.staffInvites.openInvitation
                it[numberOfStaffNeeded] = createEventRequest.staffInvites.numberOfStaffNeeded
            } get Events.id

            EventResponse(
                eventId = id.value,
                title = createEventRequest.title,
                date = createEventRequest.date,
                time = createEventRequest.time,
                location = createEventRequest.location,
                description = createEventRequest.description,
                inventoryIds = createEventRequest.inventoryIds,
                customerId = createEventRequest.customerId,
                assignedStaffIds = createEventRequest.staffInvites.specificStaffIds ?: emptyList(),
                rsvps = emptyList()
            ).also { newEvent ->
                createEventRequest.inventoryIds.forEach { inventoryId ->
                    EventInventory.insert {
                        it[eventId] = newEvent.eventId
                        it[EventInventory.inventoryId] = inventoryId
                    }
                }
                createEventRequest.staffInvites.specificStaffIds?.forEach { userId ->
                    EventStaff.insert {
                        it[eventId] = newEvent.eventId
                        it[EventStaff.userId] = userId
                    }
                }
            }
        }
    }

    fun getAllEvents(): List<EventResponse> {
        return transaction {
            Events.selectAll().map { toEventResponse(it) }
        }
    }

    fun getEventById(eventId: Int): EventResponse? {
        return transaction {
            Events.select { Events.id eq eventId }
                .mapNotNull { toEventResponse(it) }
                .singleOrNull()
        }
    }

    fun updateEvent(eventId: Int, updateEventRequest: com.teven.api.model.event.UpdateEventRequest): Boolean {
        return transaction {
            Events.update({ Events.id eq eventId }) {
                updateEventRequest.title?.let { title -> it[Events.title] = title }
                updateEventRequest.date?.let { date -> it[Events.date] = date }
                updateEventRequest.time?.let { time -> it[Events.time] = time }
                updateEventRequest.location?.let { location -> it[Events.location] = location }
                updateEventRequest.description?.let { description -> it[Events.description] = description }
                updateEventRequest.customerId?.let { customerId -> it[Events.customerId] = customerId }

                updateEventRequest.inventoryIds?.let {
                    EventInventory.deleteWhere { EventInventory.eventId eq eventId }
                    it.forEach { inventoryId ->
                        EventInventory.insert {
                            it[EventInventory.eventId] = eventId
                            it[EventInventory.inventoryId] = inventoryId
                        }
                    }
                }
                updateEventRequest.staffInvites?.let { staffInvites ->
                    staffInvites.specificStaffIds?.let {
                        EventStaff.deleteWhere { EventStaff.eventId eq eventId }
                        it.forEach { userId ->
                            EventStaff.insert {
                                it[EventStaff.eventId] = eventId
                                it[EventStaff.userId] = userId
                            }
                        }
                    }
                  staffInvites.openInvitation.let { openInvitation -> it[Events.openInvitation] = openInvitation }
                  staffInvites.numberOfStaffNeeded.let { numberOfStaffNeeded -> it[Events.numberOfStaffNeeded] = numberOfStaffNeeded }
                }
            } > 0
        }
    }

    fun deleteEvent(eventId: Int): Boolean {
        return transaction {
            Events.deleteWhere { Events.id eq eventId } > 0
        }
    }

    fun assignStaffToEvent(eventId: Int, userId: Int): Boolean {
        return transaction {
            val insertStatement = EventStaff.insert {
                it[EventStaff.eventId] = eventId
                it[EventStaff.userId] = userId
            }
            insertStatement.resultedValues?.isNotEmpty() ?: false
        }
    }

    fun removeStaffFromEvent(eventId: Int, userId: Int): Boolean {
        return transaction {
            EventStaff.deleteWhere { (EventStaff.eventId eq eventId) and (EventStaff.userId eq userId) } > 0
        }
    }

    fun rsvpToEvent(eventId: Int, userId: Int, availability: String): Boolean {
        return transaction {
            val insertStatement = Rsvps.insert {
                it[Rsvps.eventId] = eventId
                it[Rsvps.userId] = userId
                it[Rsvps.availability] = availability
            }
            insertStatement.resultedValues?.isNotEmpty() ?: false
        }
    }
}