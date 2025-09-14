package alphainterplanetary.teven.app.event

import alphainterplanetary.teven.api.model.common.failure
import alphainterplanetary.teven.api.model.common.success
import alphainterplanetary.teven.api.model.event.CreateEventRequest
import alphainterplanetary.teven.api.model.event.RsvpRequest
import alphainterplanetary.teven.api.model.event.UpdateEventRequest
import alphainterplanetary.teven.auth.withPermission
import alphainterplanetary.teven.core.security.AuthContext
import alphainterplanetary.teven.core.security.Permission.ASSIGN_TO_EVENTS_SELF
import alphainterplanetary.teven.core.security.Permission.ASSIGN_STAFF_TO_EVENTS_ORGANIZATION
import alphainterplanetary.teven.core.security.Permission.MANAGE_EVENTS_GLOBAL
import alphainterplanetary.teven.core.security.Permission.MANAGE_EVENTS_ORGANIZATION
import alphainterplanetary.teven.core.security.Permission.VIEW_EVENTS_GLOBAL
import alphainterplanetary.teven.core.security.Permission.VIEW_EVENTS_ORGANIZATION
import alphainterplanetary.teven.core.security.UserPrincipal
import alphainterplanetary.teven.service.event.EventService
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.call
import io.ktor.server.auth.principal
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.*
import org.koin.ktor.ext.inject

fun Route.eventRoutes() {
  val eventService by inject<EventService>()

  route("/api/events") {
    // Create Event
    withPermission(MANAGE_EVENTS_ORGANIZATION, MANAGE_EVENTS_GLOBAL) {
      post {
        val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
        val createEventRequest = call.receive<CreateEventRequest>()
        val newEvent = eventService.createEvent(authContext, createEventRequest)
        call.respond(HttpStatusCode.Created, success(newEvent))
      }
    }

    // Update Event
    withPermission(MANAGE_EVENTS_ORGANIZATION, MANAGE_EVENTS_GLOBAL) {
      put("{event_id}") {
        val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
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
        val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
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

    // Assign Staff to Event
    withPermission(ASSIGN_STAFF_TO_EVENTS_ORGANIZATION) {
      post("{event_id}/staff/{user_id}") {
        val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
        val eventId = call.parameters["event_id"]?.toIntOrNull()
        val userId = call.parameters["user_id"]?.toIntOrNull()
        if (eventId == null || userId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid event ID or user ID"))
          return@post
        }
        if (eventService.assignStaffToEvent(authContext, eventId, userId)) {
          call.respond(HttpStatusCode.OK, success("OK"))
        } else {
          call.respond(
            HttpStatusCode.InternalServerError,
            failure("Failed to assign staff")
          )
        }
      }

      delete("{event_id}/staff/{user_id}") {
        val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
        val eventId = call.parameters["event_id"]?.toIntOrNull()
        val userId = call.parameters["user_id"]?.toIntOrNull()
        if (eventId == null || userId == null) {
          call.respond(HttpStatusCode.BadRequest, failure("Invalid event ID or user ID"))
          return@delete
        }
        if (eventService.removeStaffFromEvent(authContext, eventId, userId)) {
          call.respond(HttpStatusCode.OK, success("OK"))
        } else {
          call.respond(
            HttpStatusCode.InternalServerError,
            failure("Failed to remove staff")
          )
        }
      }
    }

    // View Events
    withPermission(VIEW_EVENTS_ORGANIZATION, VIEW_EVENTS_GLOBAL) {
      get {
        val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
        val events = eventService.getAllEvents(authContext)
        call.respond(HttpStatusCode.OK, success(events))
      }

      get("{event_id}") {
        val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
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
    }

    // RSVP to Event
    post("{event_id}/rsvp") {
      val authContext = call.principal<UserPrincipal>()!!.toAuthContext()
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

private fun UserPrincipal.toAuthContext(): AuthContext {
  return AuthContext(userId, organizationId, permissions)
}