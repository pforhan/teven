package com.teven.app.event

import com.teven.api.model.common.StatusResponse
import com.teven.api.model.event.CreateEventRequest
import com.teven.api.model.event.RsvpRequest
import com.teven.api.model.event.UpdateEventRequest
import com.teven.auth.UserIdPrincipal
import com.teven.auth.withPermission
import com.teven.core.security.Permission.ASSIGN_STAFF_TO_EVENTS_ORGANIZATION
import com.teven.core.security.Permission.MANAGE_EVENTS_ORGANIZATION
import com.teven.core.security.Permission.VIEW_EVENTS_ORGANIZATION
import com.teven.service.event.EventService
import io.ktor.http.HttpStatusCode
import io.ktor.server.auth.principal
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.delete
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.put
import io.ktor.server.routing.route
import org.koin.ktor.ext.inject

fun Route.eventRoutes() {
  val eventService by inject<EventService>()

  route("/api/events") {
    withPermission(MANAGE_EVENTS_ORGANIZATION) {
      post {
        val createEventRequest = call.receive<CreateEventRequest>()
        val newEvent = eventService.createEvent(createEventRequest)
        call.respond(HttpStatusCode.Created, newEvent)
      }

      put("{event_id}") {
        val eventId = call.parameters["event_id"]?.toIntOrNull()
        if (eventId == null) {
          call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid event ID"))
          return@put
        }
        val updateEventRequest = call.receive<UpdateEventRequest>()
        if (eventService.updateEvent(eventId, updateEventRequest)) {
          call.respond(HttpStatusCode.OK, StatusResponse("Event with ID $eventId updated"))
        } else {
          call.respond(
            HttpStatusCode.NotFound,
            StatusResponse("Event not found or no changes applied")
          )
        }
      }

      delete("{event_id}") {
        val eventId = call.parameters["event_id"]?.toIntOrNull()
        if (eventId == null) {
          call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid event ID"))
          return@delete
        }
        if (eventService.deleteEvent(eventId)) {
          call.respond(HttpStatusCode.NoContent)
        } else {
          call.respond(HttpStatusCode.NotFound, StatusResponse("Event not found"))
        }
      }
    }

    withPermission(ASSIGN_STAFF_TO_EVENTS_ORGANIZATION) {
      post("{event_id}/staff/{user_id}") {
        val eventId = call.parameters["event_id"]?.toIntOrNull()
        val userId = call.parameters["user_id"]?.toIntOrNull()
        if (eventId == null || userId == null) {
          call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid event ID or user ID"))
          return@post
        }
        if (eventService.assignStaffToEvent(eventId, userId)) {
          call.respond(HttpStatusCode.OK, StatusResponse("OK"))
        } else {
          call.respond(
            HttpStatusCode.InternalServerError,
            StatusResponse("Failed to assign staff")
          )
        }
      }

      delete("{event_id}/staff/{user_id}") {
        val eventId = call.parameters["event_id"]?.toIntOrNull()
        val userId = call.parameters["user_id"]?.toIntOrNull()
        if (eventId == null || userId == null) {
          call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid event ID or user ID"))
          return@delete
        }
        if (eventService.removeStaffFromEvent(eventId, userId)) {
          call.respond(HttpStatusCode.OK, StatusResponse("OK"))
        } else {
          call.respond(
            HttpStatusCode.InternalServerError,
            StatusResponse("Failed to remove staff")
          )
        }
      }
    }

    withPermission(VIEW_EVENTS_ORGANIZATION) {
      get {
        val events = eventService.getAllEvents()
        call.respond(HttpStatusCode.OK, events)
      }

      get("{event_id}") {
        val eventId = call.parameters["event_id"]?.toIntOrNull()
        if (eventId == null) {
          call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid event ID"))
          return@get
        }
        val event = eventService.getEventById(eventId)
        if (event != null) {
          call.respond(HttpStatusCode.OK, event)
        } else {
          call.respond(HttpStatusCode.NotFound, StatusResponse("Event not found"))
        }
      }
    }

    post("{event_id}/rsvp") {
      val eventId = call.parameters["event_id"]?.toIntOrNull()
      if (eventId == null) {
        call.respond(HttpStatusCode.BadRequest, StatusResponse("Invalid event ID"))
        return@post
      }
      val rsvpRequest = call.receive<RsvpRequest>()
      val principal = call.principal<UserIdPrincipal>()
      val userId = principal?.userId

      if (userId == null) {
        call.respond(HttpStatusCode.Unauthorized, StatusResponse("User ID not found in token"))
        return@post
      }

      if (eventService.rsvpToEvent(eventId, userId, rsvpRequest.availability)) {
        call.respond(HttpStatusCode.OK, StatusResponse("OK"))
      } else {
        call.respond(HttpStatusCode.InternalServerError, StatusResponse("Failed to RSVP"))
      }
    }
  }
}
