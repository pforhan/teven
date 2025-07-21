## Teven Service APIs

This document outlines the API endpoints for the Teven service, including their purpose, authentication requirements, and the expected request/response data structures. Data structures are presented using Kotlin pseudocode for conciseness.

**Authentication:**
Most API endpoints in Teven will require authentication. We will use JSON Web Tokens (JWT) for authentication. The JWT will be included in the `Authorization` header of the HTTP request in the format: `Bearer <token>`. Endpoints not requiring authentication are explicitly marked.

### I. Authentication and Authorization API

* `POST /api/users/register`: Register a new user.
    * Authentication: Not required.
    * Request:
    ```kotlin
    data class RegisterRequest(
        val username: String,
        val password: String,
        val email: String,
        val role: String // e.g., "organizer", "staff"
    )
    ```
    * Response:
    ```kotlin
    data class UserResponse(
        val userId: Int,
        val username: String,
        val email: String,
        val role: String
    )
    ```

* `POST /api/users/login`: Authenticate a user and return a token.
    * Authentication: Not required.
    * Request:
    ```kotlin
    data class LoginRequest(
        val username: String,
        val password: String
    )
    ```
    * Response:
    ```kotlin
    data class LoginResponse(
        val token: String,
        val userId: Int,
        val username: String,
        val role: String
    )
    ```

* `GET /api/users/{user_id}`: Retrieve user details.
    * Authentication: Required.
    * Response:
    ```kotlin
    data class UserDetailsResponse(
        val userId: Int,
        val username: String,
        val email: String,
        val role: String,
        val staffDetails: StaffDetails? // Nullable if user is not staff
    )

    data class StaffDetails(
        val contactInformation: String,
        val skills: List<String>,
        val hoursWorked: Int,
        val phoneNumber: String,
        val dateOfBirth: String // ISO 8601 date string
    )
    ```

* `PUT /api/users/{user_id}`: Update user details.
    * Authentication: Required.
    * Request:
    ```kotlin
    data class UpdateUserRequest(
        val email: String? = null,
        val staffDetails: UpdateStaffDetails? = null
    )

    data class UpdateStaffDetails(
        val contactInformation: String? = null,
        val skills: List<String>? = null,
        val phoneNumber: String? = null,
        val dateOfBirth: String? = null // ISO 8601 date string
    )
    ```
    * Response: `UserResponse` (as defined in `GET /api/users/{user_id}`)

* `GET /api/context`: Retrieve context data for the logged-in user.
    * Authentication: Required.
    * Response:
    ```kotlin
    data class UserContextResponse(
        val user: UserResponse,
        val organization: OrganizationDetails?, // Nullable if user not part of org
        val permissions: List<String> // List of permissions for the user in current context
    )

    data class OrganizationDetails(
        val organizationId: Int,
        val name: String,
        val contactInformation: String
        // Add other relevant organization details as needed
    )
    ```

---

### II. Event API

* `POST /api/events`: Create a new event.
    * Authentication: Required.
    * Request:
    ```kotlin
    data class CreateEventRequest(
        val title: String,
        val date: String, // ISO 8601 date string (e.g., "YYYY-MM-DD")
        val time: String, // ISO 8601 time string (e.g., "HH:MM:SS")
        val location: String,
        val description: String,
        val inventoryIds: List<Int>,
        val customerId: Int, // Single customer ID
        val staffInvites: StaffInviteDetails // Details for staff invitation
    )

    data class StaffInviteDetails(
        val specificStaffIds: List<Int>? = null, // Optional: list of specific staff to invite
        val openInvitation: Boolean = false, // True if invitation is open to any staff
        val numberOfStaffNeeded: Int // Required: number of staff slots for the event
    )
    ```
    * Response:
    ```kotlin
    data class EventResponse(
        val eventId: Int,
        val title: String,
        val date: String,
        val time: String,
        val location: String,
        val description: String,
        val inventoryIds: List<Int>,
        val customerId: Int,
        val assignedStaffIds: List<Int>,
        val rsvps: List<RsvpStatus>
    )

    data class RsvpStatus(
        val userId: Int,
        val availability: String // "available" or "unavailable"
    )
    ```

* `GET /api/events`: Retrieve all events.
    * Authentication: Required.
    * Response: `List<EventResponse>`

* `GET /api/events/{event_id}`: Retrieve a specific event.
    * Authentication: Required.
    * Response: `EventResponse`

* `PUT /api/events/{event_id}`: Update an event.
    * Authentication: Required.
    * Request:
    ```kotlin
    data class UpdateEventRequest(
        val title: String? = null,
        val date: String? = null,
        val time: String? = null,
        val location: String? = null,
        val description: String? = null,
        val inventoryIds: List<Int>? = null,
        val customerId: Int? = null,
        val staffInvites: StaffInviteDetails? = null
    )
    ```
    * Response: `EventResponse`

* `DELETE /api/events/{event_id}`: Delete an event.
    * Authentication: Required.
    * Response:
    ```kotlin
    data class StatusResponse(val status: String) // "OK" on success
    ```

* `POST /api/events/{event_id}/staff/{user_id}`: Assign staff to an event.
    * Authentication: Required.
    * Response: `StatusResponse`

* `DELETE /api/events/{event_id}/staff/{user_id}`: Remove staff from an event.
    * Authentication: Required.
    * Response: `StatusResponse`

* `POST /api/events/{event_id}/rsvp`: RSVP to an event.
    * Authentication: Required.
    * Request:
    ```kotlin
    data class RsvpRequest(
        val availability: String // "available" or "unavailable"
    )
    ```
    * Response: `StatusResponse`

---

### III. Customer API

* `GET /api/customers`: Retrieve all customers.
    * Authentication: Required.
    * Response:
    ```kotlin
    data class CustomerResponse(
        val customerId: Int,
        val name: String,
        val contactInformation: String
    )
    // List<CustomerResponse>
    ```

* `GET /api/customers/{customer_id}`: Retrieve a specific customer.
    * Authentication: Required.
    * Response: `CustomerResponse`

* `POST /api/customers`: Create a new customer.
    * Authentication: Required.
    * Request:
    ```kotlin
    data class CreateCustomerRequest(
        val name: String,
        val contactInformation: String
    )
    ```
    * Response: `CustomerResponse`

* `PUT /api/customers/{customer_id}`: Update a customer.
    * Authentication: Required.
    * Request:
    ```kotlin
    data class UpdateCustomerRequest(
        val name: String? = null,
        val contactInformation: String? = null
    )
    ```
    * Response: `CustomerResponse`

* `DELETE /api/customers/{customer_id}`: Delete a customer.
    * Authentication: Required.
    * Response: `StatusResponse`

---

### IV. Inventory API

* `GET /api/inventory`: Retrieve all inventory items.
    * Authentication: Required.
    * Response:
    ```kotlin
    data class InventoryItemResponse(
        val inventoryId: Int,
        val name: String,
        val description: String,
        val quantity: Int
    )
    // List<InventoryItemResponse>
    ```

* `GET /api/inventory/{inventory_id}`: Retrieve a specific inventory item.
    * Authentication: Required.
    * Response: `InventoryItemResponse`

* `POST /api/inventory`: Create a new inventory item.
    * Authentication: Required.
    * Request:
    ```kotlin
    data class CreateInventoryItemRequest(
        val name: String,
        val description: String,
        val quantity: Int
    )
    ```
    * Response: `InventoryItemResponse`

* `PUT /api/inventory/{inventory_id}`: Update an inventory item.
    * Authentication: Required.
    * Request:
    ```kotlin
    data class UpdateInventoryItemRequest(
        val name: String? = null,
        val description: String? = null,
        val quantity: Int? = null
    )
    ```
    * Response: `InventoryItemResponse`

* `DELETE /api/inventory/{inventory_id}`: Delete an inventory item.
    * Authentication: Required.
    * Response: `StatusResponse`

* `POST /api/inventory/{inventory_id}/usage`: Track inventory item usage.
    * Authentication: Required.
    * Request:
    ```kotlin
    data class TrackInventoryUsageRequest(
        val eventId: Int,
        val quantity: Int
    )
    ```
    * Response: `StatusResponse`

---

### V. Report API

* `GET /api/reports/staff_hours`: Generate a report of staff hours worked within a date range.
    * Authentication: Required.
    * Request:
    ```kotlin
    data class StaffHoursReportRequest(
        val startDate: String, // ISO 8601 date string
        val endDate: String  // ISO 8601 date string
    )
    ```
    * Response:
    ```kotlin
    data class StaffHoursReportResponse(
        val userId: Int,
        val username: String,
        val totalHoursWorked: Int
    )
    // List<StaffHoursReportResponse>
    ```

* `GET /api/reports/inventory_usage`: Generate a report of inventory usage frequency.
    * Authentication: Required.
    * Response:
    ```kotlin
    data class InventoryUsageReportResponse(
        val inventoryId: Int,
        val name: String,
        val usageCount: Int
    )
    // List<InventoryUsageReportResponse>
    ```

---

### VI. Role Management API

* `POST /api/roles`: Create a new role.
    * Authentication: Required.
    * Request:
    ```kotlin
    data class CreateRoleRequest(
        val roleName: String,
        val permissions: List<String>
    )
    ```
    * Response:
    ```kotlin
    data class RoleResponse(
        val roleId: Int,
        val roleName: String,
        val permissions: List<String>
    )
    ```

* `GET /api/roles`: Retrieve all roles.
    * Authentication: Required.
    * Response: `List<RoleResponse>`

* `GET /api/roles/{role_id}`: Get a role by ID.
    * Authentication: Required.
    * Response: `RoleResponse`

* `PUT /api/roles/{role_id}`: Update a role.
    * Authentication: Required.
    * Request:
    ```kotlin
    data class UpdateRoleRequest(
        val roleName: String? = null,
        val permissions: List<String>? = null
    )
    ```
    * Response: `RoleResponse`

* `DELETE /api/roles/{role_id}`: Delete a role.
    * Authentication: Required.
    * Response: `StatusResponse`

* `POST /api/users/{user_id}/roles/{role_id}`: Assign a role to a user.
    * Authentication: Required.
    * Response: `StatusResponse`

* `DELETE /api/users/{user_id}/roles/{role_id}`: Remove a role from a user.
    * Authentication: Required.
    * Response: `StatusResponse`

---

**Notes:**

* This is a preliminary design and is subject to change.
* Error handling (e.g., 400 Bad Request, 404 Not Found, 500 Internal Server Error) is not detailed here but should be implemented for all endpoints.
* Input validation should be performed for all requests.
* Pagination should be implemented for endpoints that return large lists of data (e.g., `/api/events`, `/api/customers`, `/api/inventory`).
* Consider using a more descriptive name for "Availability Functionality" (e.g., "StaffAvailability").
