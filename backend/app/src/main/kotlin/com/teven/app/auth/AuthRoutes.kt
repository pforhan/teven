
package com.teven.app.auth

import com.teven.api.model.auth.LoginRequest
import com.teven.api.model.auth.RegisterRequest
import com.teven.service.user.UserService
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import io.ktor.http.HttpStatusCode
import org.koin.ktor.ext.inject

fun Route.authRoutes() {
    val userService by inject<UserService>()

    route("/api/users") {
        post("/register") {
            val registerRequest = call.receive<RegisterRequest>()
            val newUser = userService.registerUser(registerRequest)
            call.respond(HttpStatusCode.Created, newUser)
        }

        post("/login") {
            val loginRequest = call.receive<LoginRequest>()
            val loginResponse = userService.loginUser(loginRequest)
            if (loginResponse != null) {
                call.respond(HttpStatusCode.OK, loginResponse)
            } else {
                call.respond(HttpStatusCode.Unauthorized, "Invalid credentials")
            }
        }

        get("/{user_id}") {
            val userId = call.parameters["user_id"]?.toIntOrNull()
            if (userId == null) {
                call.respondText("Invalid user ID", status = io.ktor.http.HttpStatusCode.BadRequest)
                return@get
            }
                        val user = userService.getUserById(userId)
            if (user != null) {
                call.respond(HttpStatusCode.OK, user)
            } else {
                call.respond(HttpStatusCode.NotFound, "User not found")
            }
        }

        put("/{user_id}") {
            val userId = call.parameters["user_id"]?.toIntOrNull()
            if (userId == null) {
                call.respondText("Invalid user ID", status = HttpStatusCode.BadRequest)
                return@put
            }
            val updateUserRequest = call.receive<com.teven.api.model.auth.UpdateUserRequest>()
            // TODO: Implement authentication and authorization logic
            if (userService.updateUser(userId, updateUserRequest)) {
                call.respond(HttpStatusCode.OK, "User with ID $userId updated")
            } else {
                call.respond(HttpStatusCode.NotFound, "User not found or no changes applied")
            }
        }

        get("/context") {
            // TODO: Implement authentication and authorization logic to get the current user ID
            val userId = 1 // Dummy user ID for now
            val userContext = userService.getUserContext(userId)
            if (userContext != null) {
                call.respond(HttpStatusCode.OK, userContext)
            } else {
                call.respond(HttpStatusCode.NotFound, "User context not found")
            }
        }
    }
}
