
package com.teven.app.event

import com.teven.api.model.common.StatusResponse
import com.teven.api.model.event.CreateEventRequest
import com.teven.api.model.event.RsvpRequest
import com.teven.api.model.event.UpdateEventRequest
import com.teven.service.event.EventService
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import org.koin.ktor.ext.inject

fun Route.eventRoutes() {
    val eventService by inject<EventService>()

    route("/api/events") {
        post {
            val createEventRequest = call.receive<CreateEventRequest>()
            val newEvent = eventService.createEvent(createEventRequest)
            call.respond(HttpStatusCode.Created, newEvent)
        }

        get {
            val events = eventService.getAllEvents()
            call.respond(HttpStatusCode.OK, events)
        }

        get("/{event_id}") {
            val eventId = call.parameters["event_id"]?.toIntOrNull()
            if (eventId == null) {
                call.respondText("Invalid event ID", status = HttpStatusCode.BadRequest)
                return@get
            }
            val event = eventService.getEventById(eventId)
            if (event != null) {
                call.respond(HttpStatusCode.OK, event)
            } else {
                call.respond(HttpStatusCode.NotFound, "Event not found")
            }
        }

        put("/{event_id}") {
            val eventId = call.parameters["event_id"]?.toIntOrNull()
            if (eventId == null) {
                call.respondText("Invalid event ID", status = HttpStatusCode.BadRequest)
                return@put
            }
            val updateEventRequest = call.receive<UpdateEventRequest>()
            if (eventService.updateEvent(eventId, updateEventRequest)) {
                call.respond(HttpStatusCode.OK, "Event with ID $eventId updated")
            } else {
                call.respond(HttpStatusCode.NotFound, "Event not found or no changes applied")
            }
        }

        delete("/{event_id}") {
            val eventId = call.parameters["event_id"]?.toIntOrNull()
            if (eventId == null) {
                call.respondText("Invalid event ID", status = HttpStatusCode.BadRequest)
                return@delete
            }
                        if (eventService.deleteEvent(eventId)) {
                call.respond(HttpStatusCode.NoContent)
            } else {
                call.respond(HttpStatusCode.NotFound, "Event not found")
            }
        }

        post("/{event_id}/staff/{user_id}") {
            val eventId = call.parameters["event_id"]?.toIntOrNull()
            val userId = call.parameters["user_id"]?.toIntOrNull()
            if (eventId == null || userId == null) {
                call.respondText("Invalid event ID or user ID", status = HttpStatusCode.BadRequest)
                return@post
            }
            if (eventService.assignStaffToEvent(eventId, userId)) {
                call.respond(HttpStatusCode.OK, StatusResponse("OK"))
            } else {
                call.respond(HttpStatusCode.InternalServerError, StatusResponse("Failed to assign staff"))
            }
        }

        delete("/{event_id}/staff/{user_id}") {
            val eventId = call.parameters["event_id"]?.toIntOrNull()
            val userId = call.parameters["user_id"]?.toIntOrNull()
            if (eventId == null || userId == null) {
                call.respondText("Invalid event ID or user ID", status = HttpStatusCode.BadRequest)
                return@delete
            }
            if (eventService.removeStaffFromEvent(eventId, userId)) {
                call.respond(HttpStatusCode.OK, StatusResponse("OK"))
            } else {
                call.respond(HttpStatusCode.InternalServerError, StatusResponse("Failed to remove staff"))
            }
        }

        post("/{event_id}/rsvp") {
            val eventId = call.parameters["event_id"]?.toIntOrNull()
            if (eventId == null) {
                call.respondText("Invalid event ID", status = HttpStatusCode.BadRequest)
                return@post
            }
            val rsvpRequest = call.receive<RsvpRequest>()
            val userId = 1 // TODO: Get user ID from session
            if (eventService.rsvpToEvent(eventId, userId, rsvpRequest.availability)) {
                call.respond(HttpStatusCode.OK, StatusResponse("OK"))
            } else {
                call.respond(HttpStatusCode.InternalServerError, StatusResponse("Failed to RSVP"))
            }
        }
    }
}
