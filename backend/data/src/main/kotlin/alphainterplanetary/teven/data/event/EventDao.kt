package alphainterplanetary.teven.data.event

import alphainterplanetary.teven.api.model.customer.CustomerResponse
import alphainterplanetary.teven.api.model.event.CreateEventRequest
import alphainterplanetary.teven.api.model.event.EventInventoryItem
import alphainterplanetary.teven.api.model.event.EventResponse
import alphainterplanetary.teven.api.model.event.RsvpStatus
import alphainterplanetary.teven.api.model.organization.OrganizationResponse
import alphainterplanetary.teven.api.model.user.UserResponse
import alphainterplanetary.teven.data.customer.Customers
import alphainterplanetary.teven.data.dbQuery
import alphainterplanetary.teven.data.organization.Organizations
import alphainterplanetary.teven.data.user.Users
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
import org.jetbrains.exposed.sql.and
import org.jetbrains.exposed.sql.deleteWhere
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.select
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.update

class EventDao {
  private suspend fun toEventResponse(row: ResultRow): EventResponse {
    val eventId = row[Events.id]

    val inventoryItems = EventInventory.select { EventInventory.eventId eq eventId }
      .map { EventInventoryItem(it[EventInventory.inventoryItemId], it[EventInventory.quantity]) }

    val assignedStaffIds =
      EventStaff.select { EventStaff.eventId eq eventId }.map { it[EventStaff.userId].value }

    val rsvps = Rsvps.select { Rsvps.eventId eq eventId }
      .map { RsvpStatus(it[Rsvps.userId].value, it[Rsvps.availability]) }

    val organization =
      Organizations.select { Organizations.id eq row[Events.organizationId] }.single().let {
        OrganizationResponse(
          organizationId = it[Organizations.id].value,
          name = it[Organizations.name],
          contactInformation = it[Organizations.contactInformation]
        )
      }

    val customerRow = Customers.select { Customers.id eq row[Events.customerId] }.single()
    val customerOrgRow = Organizations.select { Organizations.id eq customerRow[Customers.organizationId] }.single()
    val customer = CustomerResponse(
        customerId = customerRow[Customers.id],
        name = customerRow[Customers.name],
        phone = customerRow[Customers.phone],
        address = customerRow[Customers.address],
        notes = customerRow[Customers.notes],
        organization = OrganizationResponse(
            organizationId = customerOrgRow[Organizations.id].value,
            name = customerOrgRow[Organizations.name],
            contactInformation = customerOrgRow[Organizations.contactInformation]
        )
    )

    return EventResponse(
      eventId = eventId,
      title = row[Events.title],
      date = row[Events.date],
      time = row[Events.time],
      location = row[Events.location],
      description = row[Events.description],
      inventoryItems = inventoryItems,
      customer = customer,
      assignedStaffIds = assignedStaffIds,
      rsvps = rsvps,
      organization = organization,
    )
  }

  suspend fun createEvent(createEventRequest: CreateEventRequest): EventResponse = dbQuery {
    val id = Events.insert {
      it[title] = createEventRequest.title
      it[date] = createEventRequest.date
      it[time] = createEventRequest.time
      it[location] = createEventRequest.location
      it[description] = createEventRequest.description
      it[customerId] = createEventRequest.customerId
      it[openInvitation] = createEventRequest.staffInvites.openInvitation
      it[numberOfStaffNeeded] = createEventRequest.staffInvites.numberOfStaffNeeded
      it[organizationId] = createEventRequest.organizationId
    } get Events.id

    createEventRequest.inventoryItems.forEach { item ->
        EventInventory.insert {
          it[eventId] = id
          it[inventoryItemId] = item.inventoryId
          it[quantity] = item.quantity
        }
      }
      createEventRequest.staffInvites.specificStaffIds?.forEach { userId ->
        EventStaff.insert {
          it[eventId] = id
          it[EventStaff.userId] = userId
        }
      }
      
    getEventById(id)!!
  }

  suspend fun getAllEvents(): List<EventResponse> = dbQuery {
    Events.selectAll().map { toEventResponse(it) }
  }

  suspend fun getAllEventsByOrganization(organizationId: Int): List<EventResponse> = dbQuery {
    Events.select { Events.organizationId eq organizationId }.map { toEventResponse(it) }
  }

  suspend fun getEventById(eventId: Int): EventResponse? = dbQuery {
    Events.select { Events.id eq eventId }
      .mapNotNull { toEventResponse(it) }
      .singleOrNull()
  }

  suspend fun updateEvent(
    eventId: Int,
    updateEventRequest: alphainterplanetary.teven.api.model.event.UpdateEventRequest,
  ): Boolean = dbQuery {
    Events.update({ Events.id eq eventId }) {
      updateEventRequest.title?.let { title -> it[Events.title] = title }
      updateEventRequest.date?.let { date -> it[Events.date] = date }
      updateEventRequest.time?.let { time -> it[Events.time] = time }
      updateEventRequest.location?.let { location -> it[Events.location] = location }
      updateEventRequest.description?.let { description -> it[Events.description] = description }
      updateEventRequest.customerId?.let { customerId -> it[Events.customerId] = customerId }
      updateEventRequest.organizationId?.let { organizationId ->
        it[Events.organizationId] =
          organizationId
      }

      updateEventRequest.inventoryItems?.let { inventoryItems ->
        EventInventory.deleteWhere { EventInventory.eventId eq eventId }
        inventoryItems.forEach { item ->
          EventInventory.insert { anEvInv ->
            anEvInv[EventInventory.eventId] = eventId
            anEvInv[inventoryItemId] = item.inventoryId
            anEvInv[quantity] = item.quantity
          }
        }
      }
      updateEventRequest.staffInvites?.let { staffInvites ->
        staffInvites.specificStaffIds?.let { staffUserIds ->
          EventStaff.deleteWhere { EventStaff.eventId eq eventId }
          staffUserIds.forEach { userId ->
            EventStaff.insert { aStaff ->
              aStaff[EventStaff.eventId] = eventId
              aStaff[EventStaff.userId] = userId
            }
          }
        }
        staffInvites.openInvitation.let { openInvitation ->
          it[Events.openInvitation] = openInvitation
        }
        staffInvites.numberOfStaffNeeded.let { numberOfStaffNeeded ->
          it[Events.numberOfStaffNeeded] = numberOfStaffNeeded
        }
      }
    } > 0
  }

  suspend fun deleteEvent(eventId: Int): Boolean = dbQuery {
    Events.deleteWhere { Events.id eq eventId } > 0
  }

  suspend fun assignStaffToEvent(eventId: Int, userId: Int): Boolean = dbQuery {
    val insertStatement = EventStaff.insert {
      it[EventStaff.eventId] = eventId
      it[EventStaff.userId] = userId
    }
    insertStatement.resultedValues?.isNotEmpty() ?: false
  }

  suspend fun removeStaffFromEvent(eventId: Int, userId: Int): Boolean = dbQuery {
    EventStaff.deleteWhere { (EventStaff.eventId eq eventId) and (EventStaff.userId eq userId) } > 0
  }

  suspend fun rsvpToEvent(eventId: Int, userId: Int, availability: String): Boolean = dbQuery {
    val insertStatement = Rsvps.insert {
      it[Rsvps.eventId] = eventId
      it[Rsvps.userId] = userId
      it[Rsvps.availability] = availability
    }
    insertStatement.resultedValues?.isNotEmpty() ?: false
  }

  suspend fun joinEvent(eventId: Int, userId: Int): Boolean = dbQuery {
    val existingRsvp = Rsvps.select { (Rsvps.eventId eq eventId) and (Rsvps.userId eq userId) }.singleOrNull()
    if (existingRsvp != null) {
      // User already RSVP'd, update their availability to 'available'
      Rsvps.update({ (Rsvps.eventId eq eventId) and (Rsvps.userId eq userId) }) {
        it[Rsvps.availability] = "available"
      } > 0
    } else {
      // No existing RSVP, insert a new one
      Rsvps.insert {
        it[Rsvps.eventId] = eventId
        it[Rsvps.userId] = userId
        it[Rsvps.availability] = "available"
      }.resultedValues?.isNotEmpty() ?: false
    }
  }

  suspend fun getEventsForInventoryItem(inventoryItemId: Int): List<EventResponse> = dbQuery {
    (EventInventory innerJoin Events)
      .slice(Events.columns)
      .select { EventInventory.inventoryItemId eq inventoryItemId }
      .map { toEventResponse(it) }
  }
}
