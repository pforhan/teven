package alphainterplanetary.teven.data.event

import alphainterplanetary.teven.api.model.common.PaginatedResponse
import alphainterplanetary.teven.api.model.customer.CustomerResponse
import alphainterplanetary.teven.api.model.event.CreateEventRequest
import alphainterplanetary.teven.api.model.event.EventInventoryItem
import alphainterplanetary.teven.api.model.event.EventResponse
import alphainterplanetary.teven.api.model.event.RsvpStatus
import alphainterplanetary.teven.api.model.organization.OrganizationResponse
import alphainterplanetary.teven.data.customer.Customers
import alphainterplanetary.teven.data.dbQuery
import alphainterplanetary.teven.data.inventory.InventoryItems
import alphainterplanetary.teven.data.organization.Organizations
import alphainterplanetary.teven.data.user.UserDao
import alphainterplanetary.teven.data.user.Users
import org.jetbrains.exposed.v1.core.Op
import org.jetbrains.exposed.v1.core.ResultRow
import org.jetbrains.exposed.v1.core.SortOrder
import org.jetbrains.exposed.v1.core.and
import org.jetbrains.exposed.v1.core.eq
import org.jetbrains.exposed.v1.core.greaterEq
import org.jetbrains.exposed.v1.core.lessEq
import org.jetbrains.exposed.v1.core.like
import org.jetbrains.exposed.v1.core.lowerCase
import org.jetbrains.exposed.v1.jdbc.deleteWhere
import org.jetbrains.exposed.v1.jdbc.insert
import org.jetbrains.exposed.v1.jdbc.select
import org.jetbrains.exposed.v1.jdbc.selectAll
import org.jetbrains.exposed.v1.jdbc.update

class EventDao {
  private suspend fun toEventResponse(row: ResultRow): EventResponse {
    val eventId = row[Events.id]

    val inventoryItems = EventInventory.selectAll().where { EventInventory.eventId eq eventId }
      .mapNotNull { eventInventoryRow ->
        InventoryItems.selectAll()
          .where { InventoryItems.id eq eventInventoryRow[EventInventory.inventoryItemId] }
          .singleOrNull()?.let { inventoryItemRow ->
            EventInventoryItem(
              inventoryId = eventInventoryRow[EventInventory.inventoryItemId],
              itemName = inventoryItemRow[InventoryItems.name],
              quantity = eventInventoryRow[EventInventory.quantity]
            )
          }
      }

    val rsvps = Rsvps.selectAll().where { Rsvps.eventId eq eventId }
      .mapNotNull { rsvpRow ->
        Users.selectAll().where { Users.id eq rsvpRow[Rsvps.userId] }
          .singleOrNull()?.let { userRow ->
            RsvpStatus(
              userId = rsvpRow[Rsvps.userId].value,
              displayName = userRow[Users.displayName],
              email = userRow[Users.email],
              availability = rsvpRow[Rsvps.availability]
            )
          }
      }

    val organization = Organizations.selectAll()
      .where { Organizations.id eq row[Events.organizationId] }
      .single().let {
        OrganizationResponse(
          organizationId = it[Organizations.id].value,
          name = it[Organizations.name],
          contactInformation = it[Organizations.contactInformation]
        )
      }

    val customer = row[Events.customerId]?.let { custId ->
      val customerRow = Customers.selectAll().where { Customers.id eq custId }.single()
      val customerOrgRow = Organizations.selectAll()
        .where { Organizations.id eq customerRow[Customers.organizationId] }
        .single()
      CustomerResponse(
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
    }

    return EventResponse(
      eventId = eventId,
      title = row[Events.title],
      date = row[Events.date],
      time = row[Events.time],
      durationMinutes = row[Events.durationMinutes],
      location = row[Events.location],
      description = row[Events.description],
      inventoryItems = inventoryItems,
      customer = customer,
      rsvps = rsvps,
      organization = organization,
      openInvitation = row[Events.openInvitation],
      numberOfStaffNeeded = row[Events.numberOfStaffNeeded],
    )
  }

  suspend fun createEvent(createEventRequest: CreateEventRequest): EventResponse = dbQuery {
    val id = Events.insert {
      it[title] = createEventRequest.title
      it[date] = createEventRequest.date
      it[time] = createEventRequest.time
      it[durationMinutes] = createEventRequest.durationMinutes
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
      Rsvps.insert {
        it[eventId] = id
        it[Rsvps.userId] = userId
        it[availability] = "requested"
      }
    }

    getEventByIdBare(id)!!
  }

  suspend fun getEvents(
    organizationId: Int?,
    startDate: String?,
    endDate: String?,
    search: String?,
    limit: Int?,
    offset: Long?,
    sortOrder: String?,
  ): PaginatedResponse<EventResponse> = dbQuery {
    val conditions = mutableListOf<Op<Boolean>>()
    organizationId?.let { conditions.add(Events.organizationId eq it) }
    startDate?.let { conditions.add(Events.date greaterEq it) }
    endDate?.let { conditions.add(Events.date lessEq it) }
    search?.let { conditions.add(Events.title.lowerCase() like "%${it.lowercase()}%") }

    val query = if (conditions.isEmpty()) {
      Events.selectAll()
    } else {
      val combinedCondition = conditions.reduce { acc, op -> acc and op }
      Events.selectAll().where { combinedCondition }
    }

    val total = query.count()

    val sort = if (sortOrder == "desc") SortOrder.DESC else SortOrder.ASC
    query.orderBy(Events.date, sort)

    offset?.let { query.offset(it) }
    limit?.let { query.limit(it) }

    val events = query.map { toEventResponse(it) }

    PaginatedResponse(
      items = events,
      total = total,
      offset = offset ?: 0,
      limit = limit ?: 0,
    )
  }

  private suspend fun getEventByIdBare(eventId: Int): EventResponse? = Events.selectAll().where { Events.id eq eventId }
    .mapNotNull { toEventResponse(it) }
    .singleOrNull()

  suspend fun getEventById(eventId: Int): EventResponse? = dbQuery {
    getEventByIdBare(eventId)
  }

  suspend fun updateEvent(
    eventId: Int,
    updateEventRequest: alphainterplanetary.teven.api.model.event.UpdateEventRequest,
  ): Boolean = dbQuery {
    Events.update({ Events.id eq eventId }) {
      updateEventRequest.title?.let { title -> it[Events.title] = title }
      updateEventRequest.date?.let { date -> it[Events.date] = date }
      updateEventRequest.time?.let { time -> it[Events.time] = time }
      updateEventRequest.durationMinutes?.let { minutes -> it[Events.durationMinutes] = minutes }
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
        // Clear existing 'requested' RSVPs for this event to handle deselections
        Rsvps.deleteWhere { (Rsvps.eventId eq eventId) and (Rsvps.availability eq "requested") }

        staffInvites.specificStaffIds?.let { specificStaffIds ->
          for (userId in specificStaffIds) {
            val existingRsvp = Rsvps.selectAll().where { (Rsvps.eventId eq eventId) and (Rsvps.userId eq userId) }.singleOrNull()
            if (existingRsvp != null) {
              Rsvps.update({ (Rsvps.eventId eq eventId) and (Rsvps.userId eq userId) }) {
                it[Rsvps.availability] = "requested"
              }
            } else {
              Rsvps.insert {
                it[Rsvps.eventId] = eventId
                it[Rsvps.userId] = userId
                it[Rsvps.availability] = "requested"
              }
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

  suspend fun rsvpToEvent(eventId: Int, userId: Int, availability: String): Boolean = dbQuery {
    val existingRsvp =
      Rsvps.selectAll().where { (Rsvps.eventId eq eventId) and (Rsvps.userId eq userId) }.singleOrNull()
    if (existingRsvp != null) {
      // User already RSVP'd, update their availability
      Rsvps.update({ (Rsvps.eventId eq eventId) and (Rsvps.userId eq userId) }) {
        it[Rsvps.availability] = availability
      } > 0
    } else {
      // No existing RSVP, insert a new one
      Rsvps.insert {
        it[Rsvps.eventId] = eventId
        it[Rsvps.userId] = userId
        it[Rsvps.availability] = availability
      }.resultedValues?.isNotEmpty() ?: false
    }
  }

  suspend fun getEventsForInventoryItem(inventoryItemId: Int): List<EventResponse> = dbQuery {
    (EventInventory innerJoin Events)
      .select(Events.columns)
      .where { EventInventory.inventoryItemId eq inventoryItemId }
      .map { toEventResponse(it) }
  }

  suspend fun getRequestedRsvpEventsForUser(userId: Int): List<EventResponse> = dbQuery {
    val eventIds = Rsvps.selectAll()
      .where { (Rsvps.userId eq userId) and (Rsvps.availability eq "requested") }
      .map { it[Rsvps.eventId] }

    eventIds.mapNotNull { eventId ->
      getEventById(eventId)
    }
  }
}
