package com.teven.data.event

import com.teven.api.model.event.EventResponse
import com.teven.api.model.event.RsvpStatus
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.select

object Events : Table() {
  val id = integer("id").autoIncrement()
  val title = varchar("title", 255)
  val date = varchar("date", 255)
  val time = varchar("time", 255)
  val location = varchar("location", 255)
  val description = text("description")
  val customerId = integer("customer_id").references(com.teven.data.customer.Customers.id)
  val openInvitation = bool("open_invitation")
  val numberOfStaffNeeded = integer("number_of_staff_needed")

  override val primaryKey = PrimaryKey(id)

  fun toEventResponse(row: ResultRow): EventResponse {
    val eventId = row[id]

    val inventoryIds = EventInventory.select { EventInventory.eventId eq eventId }
      .map { it[EventInventory.inventoryId].value }

    val assignedStaffIds =
      EventStaff.select { EventStaff.eventId eq eventId }.map { it[EventStaff.userId].value }

    val rsvps = Rsvps.select { Rsvps.eventId eq eventId }
      .map { RsvpStatus(it[Rsvps.userId].value, it[Rsvps.availability]) }

    return EventResponse(
      eventId = eventId,
      title = row[title],
      date = row[date],
      time = row[time],
      location = row[location],
      description = row[description],
      inventoryIds = inventoryIds,
      customerId = row[customerId],
      assignedStaffIds = assignedStaffIds,
      rsvps = rsvps
    )
  }
}