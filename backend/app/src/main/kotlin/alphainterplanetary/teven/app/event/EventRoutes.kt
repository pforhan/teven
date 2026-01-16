package alphainterplanetary.teven.app.event

import alphainterplanetary.teven.api.model.common.failure
import alphainterplanetary.teven.api.model.common.success
import alphainterplanetary.teven.api.model.event.CreateEventRequest
import alphainterplanetary.teven.api.model.event.RsvpRequest
import alphainterplanetary.teven.api.model.event.UpdateEventRequest
import alphainterplanetary.teven.app.requireAuthContext
import alphainterplanetary.teven.auth.withPermission
import alphainterplanetary.teven.core.security.Permission.MANAGE_EVENTS_GLOBAL
import alphainterplanetary.teven.core.security.Permission.MANAGE_EVENTS_ORGANIZATION
import alphainterplanetary.teven.core.security.Permission.VIEW_EVENTS_GLOBAL
import alphainterplanetary.teven.core.security.Permission.VIEW_EVENTS_ORGANIZATION
import alphainterplanetary.teven.service.event.EventService
import io.ktor.http.HttpStatusCode
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
    // Create Event
    withPermission(MANAGE_EVENTS_ORGANIZATION, MANAGE_EVENTS_GLOBAL) {
      post {
        val authContext = requireAuthContext()
        val createEventRequest = call.receive<CreateEventRequest>()
        val newEvent = eventService.createEvent(authContext, createEventRequest)
        call.respond(HttpStatusCode.Created, success(newEvent))
      }
    }

    // Update Event
    withPermission(MANAGE_EVENTS_ORGANIZATION, MANAGE_EVENTS_GLOBAL) {
      put("{event_id}") {
        val authContext = requireAuthContext()
        val eventId = call.parameters["event_id"]?.toIntOrNull()
        if (eventId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid event ID"))
          return@put
        }
        val updateEventRequest = call.receive<UpdateEventRequest>()
        if (eventService.updateEvent(authContext, eventId, updateEventRequest)) {
          call.respond(HttpStatusCode.OK, success("Event with ID $eventId updated"))
        } else {
          call.respond(
            HttpStatusCode.NotFound,
            failure("Event not found or no changes applied")
          )
        }
      }
    }

    // Delete Event
    withPermission(MANAGE_EVENTS_ORGANIZATION, MANAGE_EVENTS_GLOBAL) {
      delete("{event_id}") {
        val authContext = requireAuthContext()
        val eventId = call.parameters["event_id"]?.toIntOrNull()
        if (eventId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid event ID"))
          return@delete
        }
        if (eventService.deleteEvent(authContext, eventId)) {
          call.respond(HttpStatusCode.NoContent)
        } else {
          call.respond(HttpStatusCode.NotFound, failure("Event not found"))
        }
      }
    }

    // View Events
    withPermission(VIEW_EVENTS_ORGANIZATION, VIEW_EVENTS_GLOBAL) {
      get {
        val authContext = requireAuthContext()
        val startDate = call.request.queryParameters["startDate"]
        val endDate = call.request.queryParameters["endDate"]
        val limit = call.request.queryParameters["limit"]?.toIntOrNull()
        val offset = call.request.queryParameters["offset"]?.toLongOrNull()
        val sortOrder = call.request.queryParameters["sortOrder"] ?: "asc"
        val organizationId = call.request.queryParameters["organizationId"]?.toIntOrNull()

        val events = eventService.getEvents(
          authContext = authContext,
          startDate = startDate,
          endDate = endDate,
          limit = limit,
          offset = offset,
          sortOrder = sortOrder,
          organizationId = organizationId,
        )
        call.respond(HttpStatusCode.OK, success(events))
      }

      get("{event_id}") {
        val authContext = requireAuthContext()
        val eventId = call.parameters["event_id"]?.toIntOrNull()
        if (eventId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid event ID"))
          return@get
        }
        val event = eventService.getEventById(authContext, eventId)
        if (event != null) {
          call.respond(HttpStatusCode.OK, success(event))
        } else {
          call.respond(HttpStatusCode.NotFound, failure("Event not found"))
        }
      }

      get("/rsvps/requested") {
        val authContext = requireAuthContext()
        val userId = authContext.userId

        val requestedRsvps = eventService.getRequestedRsvpEventsForUser(userId)
        call.respond(HttpStatusCode.OK, success(requestedRsvps))
      }
    }

    // RSVP to Event
    post("{event_id}/rsvp") {
      val authContext = requireAuthContext()
      val eventId = call.parameters["event_id"]?.toIntOrNull()
      if (eventId == null) {
        call.respond(HttpStatusCode.BadRequest, failure("Invalid event ID"))
        return@post
      }
      val rsvpRequest = call.receive<RsvpRequest>()
      val userId = authContext.userId // RSVPing for self

      if (eventService.rsvpToEvent(authContext, eventId, userId, rsvpRequest.availability)) {
        call.respond(HttpStatusCode.OK, success("OK"))
      } else {
        call.respond(HttpStatusCode.InternalServerError, failure("Failed to RSVP"))
      }
    }
  }
}